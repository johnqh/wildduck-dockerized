#!/bin/bash

# This script deploys the frontend (WildDuck Webmail) service.
# It prompts for various configuration details and then sets up
# Docker containers for the frontend components (wildduck-webmail, redis, traefik).

# Define directories for frontend configuration
FRONTEND_CONFIG_DIR="./frontend-config"
# Path to the default webmail config provided by the user
DEFAULT_WEBMAIL_CONFIG_SOURCE="./default-config/wildduck-webmail/default.toml"
# Path to the base docker-compose.yml provided by the user
BASE_DOCKER_COMPOSE_SOURCE="./docker-compose.yml"

# --- Functions ---

# Function to display error messages and exit
function error_exit {
    echo "Error: $1" >&2
    exit 1
}

# Function to clean up old configurations
function clean_up {
    echo "Cleaning up old frontend configuration files and folders..."
    echo "Are you sure you want to remove the '$FRONTEND_CONFIG_DIR' directory? [Y/n] "
    read -r yn # Use -r to prevent backslash interpretation
    case $yn in
        [Yy]* )
            sudo rm -rf "$FRONTEND_CONFIG_DIR" || error_exit "Failed to remove $FRONTEND_CONFIG_DIR"
            echo "Clean up complete."
            ;;
        [Nn]* )
            echo "No files and folders removed. Continuing with deployment..."
            ;;
        * )
            echo "Invalid input. Assuming 'yes'. Removing $FRONTEND_CONFIG_DIR..."
            sudo rm -rf "$FRONTEND_CONFIG_DIR" || error_exit "Failed to remove $FRONTEND_CONFIG_DIR"
            echo "Clean up complete."
            ;;
    esac
}

# Function to prompt for hostname
function get_hostname {
    echo "--- Frontend Setup Configuration ---"
    if [ "$#" -gt "0" ]; then
        HOSTNAME=${args[0]}
        echo -e "Using Frontend HOSTNAME: $HOSTNAME"
    else
        echo "Specify the HOSTNAME for your webmail (e.g., webmail.example.com): "
        read -r HOSTNAME
    fi

    if [ -z "$HOSTNAME" ]; then
        error_exit "Frontend Hostname cannot be empty."
    fi
}

# Function to prepare frontend configuration directories and copy base files
function prepare_config_dirs {
    echo "Preparing frontend configuration directories..."
    # Create the nested config-generated directory for webmail config
    mkdir -p "$FRONTEND_CONFIG_DIR"/config-generated/wildduck-webmail || error_exit "Failed to create $FRONTEND_CONFIG_DIR/config-generated/wildduck-webmail"

    # Copy the default webmail config file into the nested directory
    if [ ! -f "$DEFAULT_WEBMAIL_CONFIG_SOURCE" ]; then
        error_exit "Default webmail config file not found at $DEFAULT_WEBMAIL_CONFIG_SOURCE. Please ensure it exists."
    fi
    cp "$DEFAULT_WEBMAIL_CONFIG_SOURCE" "$FRONTEND_CONFIG_DIR"/config-generated/wildduck-webmail/default.toml || error_exit "Failed to copy default webmail config"

    # Copy the base docker-compose.yml into the frontend config directory
    if [ ! -f "$BASE_DOCKER_COMPOSE_SOURCE" ]; then
        error_exit "Base docker-compose.yml not found at $BASE_DOCKER_COMPOSE_SOURCE. Please ensure it's in the same directory as this script."
    fi
    cp "$BASE_DOCKER_COMPOSE_SOURCE" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to copy base docker-compose.yml"

    echo "Configuration directories and docker-compose.yml prepared."
}

# Function to apply hostname, API token, API URL, and Redis config to webmail
function apply_frontend_configs {
    echo "Applying hostname and connection details to webmail configuration..."

    FRONTEND_DOCKER_COMPOSE="$FRONTEND_CONFIG_DIR/docker-compose.yml"
    WEBMAIL_CONFIG_FILE="$FRONTEND_CONFIG_DIR/config-generated/wildduck-webmail/default.toml"

    # --- Modify the copied docker-compose.yml ---

    # Remove services not needed for the frontend deployment: wildduck, zonemta, haraka, rspamd, mongo
    # This pattern deletes lines from the service name (at 2 spaces indentation) until the next line that is
    # either another service name (also at 2 spaces indentation) or a line with less indentation (e.g., 'volumes:')
    # It handles cases where services are not separated by blank lines.

    # Remove wildduck service block
    sed -i '/^  wildduck:/,/^  wildduck-webmail:/{//!d; /^  wildduck:/d}' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to remove wildduck service block"
    # Remove zonemta service block
    sed -i '/^  zonemta:/,/^  haraka:/{//!d; /^  zonemta:/d}' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to remove zonemta service block"
    # Remove haraka service block
    sed -i '/^  haraka:/,/^  rspamd:/{//!d; /^  haraka:/d}' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to remove haraka service block"
    # Remove rspamd service block
    sed -i '/^  rspamd:/,/^  mongo:/{//!d; /^  rspamd:/d}' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to remove rspamd service block"
    # Remove mongo service block (assuming it's before redis or at the end of services if redis is removed)
    # We remove from mongo: until redis: but ensure redis: itself is not deleted.
    sed -i '/^  mongo:/,/^  redis:/{//!d; /^  mongo:/d}' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to remove mongo service block"

    # Remove associated volumes for removed services from the main volumes block
    sed -i '/^  mongo:/d' "$FRONTEND_DOCKER_COMPOSE" || true # Remove mongo volume

    # Adjust wildduck-webmail volumes path to point to config-generated
    sed -i "s|./config/wildduck-webmail:/app/config|./config-generated/wildduck-webmail:/app/config|g" "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to adjust webmail volume path"

    # Ensure wildduck-webmail does not depend on the backend wildduck service
    # The base docker-compose.yml has it commented, so if it somehow becomes uncommented
    sed -i 's|^\(      - wildduck\)|\#\1|' "$FRONTEND_DOCKER_COMPOSE" || true
    # Commenting out mongo dependency as requested
    sed -i 's|^\(      - mongo\)|\#\1|' "$FRONTEND_DOCKER_COMPOSE" || true

    # Remove other TCP entrypoints and associated labels/services in Traefik not needed for frontend-only
    # These lines are specific to the provided docker-compose.yml's structure
    sed -i '/- "--entrypoints.imaps.address=:993"/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/- "--entrypoints.pop3s.address=:995"/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/- "--entrypoints.smtps.address=:465"/d' "$FRONTEND_DOCKER_COMPOSE" || true

    sed -i '/traefik.tcp.routers.wildduck-imaps/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.wildduck-imaps.rule/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/# traefik.tcp.routers.wildduck-imaps.tls.certresolver/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.wildduck-imaps.tls/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.wildduck-imaps.service/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.services.wildduck-imaps.loadbalancer.server.port/d' "$FRONTEND_DOCKER_COMPOSE" || true

    sed -i '/traefik.tcp.routers.wildduck-pop3s/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.wildduck-pop3s.rule/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/# traefik.tcp.routers.wildduck-pop3s.tls.certresolver/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.wildduck-pop3s.tls/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.wildduck-pop3s.service/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.services.wildduck-pop3s.loadbalancer.server.port/d' "$FRONTEND_DOCKER_COMPOSE" || true

    sed -i '/traefik.tcp.routers.zonemta/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.zonemta.rule/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.zonemta.tls/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.routers.zonemta.service/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.tcp.services.zonemta.loadbalancer.server.port/d' "$FRONTEND_DOCKER_COMPOSE" || true

    # Remove wildduck-api-path router and middleware as it's backend related
    sed -i '/traefik.http.routers.wildduck-api-path/d' "$FRONTEND_DOCKER_COMPOSE" || true
    sed -i '/traefik.http.middlewares.wildduck-api-stripprefix/d' "$FRONTEND_DOCKER_COMPOSE" || true

    # Replace HOSTNAME placeholder in docker-compose.yml for frontend Traefik rules
    sed -i "s|HOSTNAME|$HOSTNAME|g" "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to replace HOSTNAME in docker-compose.yml"


    # --- Modify default.toml for WildDuck Webmail ---

    # Prompt for API Token
    echo "Enter the WildDuck API Token (from backend setup): "
    read -r API_TOKEN
    if [ -z "$API_TOKEN" ]; then
        error_exit "API Token cannot be empty."
    fi
    sed -i "s|accessToken=\"\"|accessToken=\"$API_TOKEN\"|g" "$WEBMAIL_CONFIG_FILE" || error_exit "Failed to update API Token in webmail config"

    # Prompt for Mail Server Hostname and construct API URL
    echo "Enter the Mail Server Hostname (e.g., mail.example.com): "
    read -r MAIL_SERVER_HOSTNAME
    if [ -z "$MAIL_SERVER_HOSTNAME" ]; then
        error_exit "Mail Server Hostname cannot be empty."
    fi
    API_URL="https://$MAIL_SERVER_HOSTNAME"
    sed -i "s|url=\"http://wildduck:8080\"|url=\"$API_URL\"|g" "$WEBMAIL_CONFIG_FILE" || error_exit "Failed to update API URL in webmail config"

    # MongoDB URL: Keep as is, as per request (no prompt, no modification)
    echo "Using default MongoDB configuration for frontend: mongodb://mongo:27017/wildduck-webmail"

    # Update Redis DB config for frontend (using its own Redis instance) - default.toml already points to 'redis'
    echo "Using default Redis configuration for frontend: redis://redis:6379/5"
    # Ensure the `depends_on` for redis is present for wildduck-webmail
    if ! grep -q "wildduck-webmail.*depends_on:.*- redis" "$FRONTEND_DOCKER_COMPOSE"; then
        sed -i "/wildduck-webmail:/!b;n;/depends_on:/a\      - redis" "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to add redis dependency to webmail service"
    fi

    # Update hostname related fields in webmail config (service and u2f appId)
    MAILDOMAIN=$(echo "$HOSTNAME" | sed 's/^[^.]*\.//') # Extract domain from frontend hostname
    if [ -z "$MAILDOMAIN" ]; then
        MAILDOMAIN=$HOSTNAME # Fallback if no subdomain
    fi
  

    sed -i "s|example\.com|$MAIL_SERVER_HOSTNAME|g" "$WEBMAIL_CONFIG_FILE" || error_exit "Failed to update domain in webmail config"
    echo "Frontend configurations applied."
}

# Function to handle SSL certificate setup for frontend
function setup_ssl {
    echo "--- Frontend SSL Certificate Setup ---"
    echo "Do you wish to set up self-signed certs for development for the frontend? (y/N) "
    read -r yn
    USE_SELF_SIGNED_CERTS=false
    case $yn in
        [Yy]* ) USE_SELF_SIGNED_CERTS=true;;
        [Nn]* ) USE_SELF_SIGNED_CERTS=false;;
        * ) USE_SELF_SIGNED_CERTS=false;;
    esac

    FRONTEND_DOCKER_COMPOSE="$FRONTEND_CONFIG_DIR/docker-compose.yml"

    if $USE_SELF_SIGNED_CERTS; then
        echo "Generating self-signed TLS Certs for frontend..."
        mkdir -p "$FRONTEND_CONFIG_DIR"/certs || error_exit "Failed to create certs directory for frontend"
        mkdir -p "$FRONTEND_CONFIG_DIR"/dynamic_conf || error_exit "Failed to create dynamic_conf directory for frontend" # Needed for file provider

        openssl genrsa -out "$FRONTEND_CONFIG_DIR"/certs/rootCA.key 4096 || error_exit "Failed to generate root CA key for frontend"
        openssl req -x509 -new -nodes -key "$FRONTEND_CONFIG_DIR"/certs/rootCA.key -sha256 -days 3650 -out "$FRONTEND_CONFIG_DIR"/certs/rootCA.pem -subj "/C=US/ST=State/L=City/O=Your Organization/CN=Your CA Frontend" || error_exit "Failed to generate root CA cert for frontend"
        openssl genrsa -out "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".key 2048 || error_exit "Failed to generate hostname key for frontend"
        openssl req -new -key "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".key -out "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".csr -subj "/C=US/ST=State/L=City/O=Your Organization/CN=$HOSTNAME" || error_exit "Failed to generate hostname CSR for frontend"
        cat > "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $HOSTNAME
DNS.2 = *.$HOSTNAME
EOF
        openssl x509 -req -in "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".csr -CA "$FRONTEND_CONFIG_DIR"/certs/rootCA.pem -CAkey "$FRONTEND_CONFIG_DIR"/certs/rootCA.key -CAcreateserial -out "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".crt -days 825 -sha256 -extfile "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".ext || error_exit "Failed to sign hostname cert for frontend"
        mv "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".crt "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".pem || error_exit "Failed to rename cert for frontend"
        mv "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME".key "$FRONTEND_CONFIG_DIR"/certs/"$HOSTNAME"-key.pem || error_exit "Failed to rename key for frontend"
        echo "Self-signed TLS Certs generated for frontend."

        # Traefik configuration for self-signed:
        # Uncomment providers.file lines (they are commented in base compose)
        sed -i 's/^# \( *- "--providers.file=true"\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment providers.file"
        sed -i 's/^# \( *- "--providers.file.directory=\/etc\/traefik\/dynamic_conf"\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment providers.file.directory"
        sed -i 's/^# \( *- "--providers.file.watch=true"\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment providers.file.watch"
        sed -i 's/^# \( *- "--serversTransport.insecureSkipVerify=true"\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment serversTransport.insecureSkipVerify"
        sed -i 's/^# \( *- "--serversTransport.rootCAs=\/etc\/traefik\/certs\/rootCA.pem"\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment serversTransport.rootCAs"

        # Comment out certificatesresolvers.letsencrypt lines (they are uncommented in base compose)
        sed -i 's/^\( *- "--certificatesresolvers.letsencrypt.acme.email=.*\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--certificatesresolvers.letsencrypt.acme.storage=.*\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        
        # Uncomment certs and dynamic_conf volumes
        # These lines are already present in the base docker-compose.yml under Traefik's volumes, but commented out.
        sed -i 's/^# \( *- .\/certs:\/etc\/traefik\/certs\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment certs volume"
        sed -i 's/^# \( *- .\/dynamic_conf:\/etc\/traefik\/dynamic_conf:ro\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment dynamic_conf volume"

        # Change webmail Traefik labels: use tls: true instead of certresolver
        # This line should be uncommented when using self-signed certs
        sed -i 's|^# \( *traefik.http.routers.wildduck-webmail.tls: true\)|\1|g' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment webmail tls label"
        # This line should be commented when using self-signed certs
        sed -i 's|^\( *traefik.http.routers.wildduck-webmail.tls.certresolver: letsencrypt\)|\#\1|g' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to comment webmail certresolver label"


    else # Using Let's Encrypt
        echo "Configuring for Let's Encrypt for frontend..."
        MAILDOMAIN=$(echo "$HOSTNAME" | sed 's/^[^.]*\.//') # Extract domain from hostname
        if [ -z "$MAILDOMAIN" ]; then
            MAILDOMAIN=$HOSTNAME # Fallback if no subdomain
        fi

        # Comment out providers.file lines (they are uncommented in base compose)
        sed -i 's/^\( *- "--providers.file=true"\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--providers.file.directory=\/etc\/traefik\/dynamic_conf"\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--providers.file.watch=true"\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--serversTransport.insecureSkipVerify=true"\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--serversTransport.rootCAs=\/etc\/traefik\/certs\/rootCA.pem"\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true

        # Uncomment certificatesresolvers.letsencrypt lines (they are commented in base compose)
        # Ensure correct indentation and replacement for ACME_EMAIL
        sed -i "s/^# \( *- \"--certificatesresolvers.letsencrypt.acme.email=ACME_EMAIL\"\)/      - \"--certificatesresolvers.letsencrypt.acme.email=webmaster@$MAILDOMAIN\"/" "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment LE email"
        sed -i 's/^# \( *- "--certificatesresolvers.letsencrypt.acme.storage=.*\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment LE storage"
        sed -i 's/^# \( *- "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"\)/\1/' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment LE tlschallenge"

        # Comment out certs and dynamic_conf volumes
        # These lines are already present in the base docker-compose.yml under Traefik's volumes, but commented out.
        sed -i 's/^\( *- .\/certs:\/etc\/traefik\/certs\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- .\/dynamic_conf:\/etc\/traefik\/dynamic_conf:ro\)/# \1/' "$FRONTEND_DOCKER_COMPOSE" || true
        
        # # Change webmail Traefik labels: use certresolver instead of tls: true
        # # This line should be commented when using Let's Encrypt
        # sed -i 's|^\( *traefik.http.routers.wildduck-webmail.tls: true\)|\#\1|g' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to comment webmail tls label"
        # # This line should be uncommented when using Let's Encrypt
        # sed -i 's|^# \( *traefik.http.routers.wildduck-webmail.tls.certresolver: letsencrypt\)|\1|g' "$FRONTEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment webmail certresolver label"
    fi
}


# --- Main Script Execution ---

args=("$@")

clean_up


source "./setup-scripts/deps_setup.sh"

get_hostname "${args[@]}"
prepare_config_dirs
apply_frontend_configs
setup_ssl # Call the SSL setup function

echo "Stopping any existing frontend containers..."
sudo docker compose -f "$FRONTEND_CONFIG_DIR"/docker-compose.yml down || echo "No existing frontend containers to stop."

echo "Deploying frontend services..."
cd "$FRONTEND_CONFIG_DIR" || error_exit "Failed to change directory to $FRONTEND_CONFIG_DIR"
sudo docker compose up -d || error_exit "Failed to deploy frontend service"
cd .. # Go back to original directory

echo "Frontend deployment complete! Access your webmail at https://$HOSTNAME"
