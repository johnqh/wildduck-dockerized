#!/bin/bash

# This script deploys the backend services of the WildDuck mail server.
# It sets up the necessary configurations, handles SSL certificates (self-signed or Let's Encrypt),
# performs MongoDB setup, and optionally DNS setup.
# It ensures the WildDuck Webmail service is NOT deployed with the backend.

# Define directories for backend configuration
CONFIG_DIR="./backend-config"
DEFAULT_CONFIG_SOURCE="./default-config"
DYNAMIC_CONF_SOURCE="./dynamic_conf"
BASE_DOCKER_COMPOSE_SOURCE="./docker-compose.yml" # Assuming the base docker-compose.yml is here
SETUP_SCRIPTS_DIR="./setup-scripts" # Directory for helper scripts like mongo.sh, dns_setup.sh

# Global variables to store generated secrets for printing at the end
ACCESS_TOKEN=""
GENERATED_API_URL=""

# --- Functions ---

# Function to display error messages and exit
function error_exit {
    echo "Error: $1" >&2
    exit 1
}

# Function to clean up old configurations
function clean_up {
    echo "Cleaning up old backend configuration files and folders..."
    echo "Are you sure you want to remove the '$CONFIG_DIR' directory, 'acme.json', and 'update_certs.sh'? [Y/n] "
    read -r yn # Use -r to prevent backslash interpretation
    case $yn in
        [Yy]* )
            sudo rm -rf "$CONFIG_DIR" || error_exit "Failed to remove $CONFIG_DIR"
            sudo rm -rf ./acme.json || echo "acme.json not found, skipping removal." # Allow skipping if not exists
            sudo rm -rf update_certs.sh || echo "update_certs.sh not found, skipping removal."
            echo "Clean up complete."
            ;;
        [Nn]* )
            echo "No files and folders removed. Exiting..."
            exit 0 # Exit cleanly if user chooses not to clean up
            ;;
        * )
            echo "Invalid input. Assuming 'yes'. Removing $CONFIG_DIR, acme.json, and update_certs.sh..."
            sudo rm -rf "$CONFIG_DIR" || error_exit "Failed to remove $CONFIG_DIR"
            sudo rm -rf ./acme.json || echo "acme.json not found, skipping removal."
            sudo rm -rf update_certs.sh || echo "update_certs.sh not found, skipping removal."
            echo "Clean up complete."
            ;;
    esac
}


# Function to prompt for domain and hostname
function get_domain_and_hostname {
    echo "--- Backend Setup Configuration ---"
    if [ "$#" -gt "0" ]; then
        MAILDOMAIN=${args[0]}
        HOSTNAME=${args[1]:-$MAILDOMAIN}
        echo -e "Using DOMAINNAME: $MAILDOMAIN, HOSTNAME: $HOSTNAME"
    else
        echo "Specify the MAILDOMAIN (e.g., example.com): "
        read -r MAILDOMAIN
        if [ -z "$MAILDOMAIN" ]; then
            error_exit "Maildomain cannot be empty."
        fi

        echo "Specify the HOSTNAME for your mail server (e.g., mail.example.com). If left empty, MAILDOMAIN will be used: "
        read -r HOSTNAME
        if [ -z "$HOSTNAME" ]; then
            HOSTNAME=$MAILDOMAIN
        fi
    fi

    echo "Using MAILDOMAIN: $MAILDOMAIN, HOSTNAME: $HOSTNAME"
}

# Function to prepare config directories and copy base files
function prepare_config_dirs {
    echo "Preparing backend configuration directories..."
    mkdir -p "$CONFIG_DIR"/config/wildduck || error_exit "Failed to create wildduck config directory"
    mkdir -p "$CONFIG_DIR"/config/zonemta || error_exit "Failed to create zonemta config directory"
    mkdir -p "$CONFIG_DIR"/config/haraka || error_exit "Failed to create haraka config directory"
    mkdir -p "$CONFIG_DIR"/config/rspamd || error_exit "Failed to create rspamd config directory"

    # Copy default configs
    cp "$DEFAULT_CONFIG_SOURCE"/wildduck/default.toml "$CONFIG_DIR"/config/wildduck/default.toml || error_exit "Failed to copy wildduck default config"
    cp "$DEFAULT_CONFIG_SOURCE"/zonemta/config.toml "$CONFIG_DIR"/config/zonemta/config.toml || error_exit "Failed to copy zonemta config"
    cp "$DEFAULT_CONFIG_SOURCE"/haraka/config.js "$CONFIG_DIR"/config/haraka/config.js || error_exit "Failed to copy haraka config"
    cp "$DEFAULT_CONFIG_SOURCE"/rspamd/local.d/dkim_signing.conf "$CONFIG_DIR"/config/rspamd/local.d/dkim_signing.conf || error_exit "Failed to copy rspamd dkim config"
    cp "$DEFAULT_CONFIG_SOURCE"/rspamd/override.local.d/metrics.conf "$CONFIG_DIR"/config/rspamd/override.local.d/metrics.conf || error_exit "Failed to copy rspamd metrics config"

    # Copy the base docker-compose.yml into the backend config directory
    if [ ! -f "$BASE_DOCKER_COMPOSE_SOURCE" ]; then
        error_exit "Base docker-compose.yml not found at $BASE_DOCKER_COMPOSE_SOURCE. Please ensure it's in the same directory as this script."
    fi
    cp "$BASE_DOCKER_COMPOSE_SOURCE" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to copy base docker-compose.yml"

    echo "Configuration directories and docker-compose.yml prepared."
}

# Function to apply hostname and secrets to backend configs
function apply_backend_configs {
    echo "Applying hostname and secrets to backend configurations..."

    BACKEND_DOCKER_COMPOSE="$CONFIG_DIR/docker-compose.yml"
    WILDUCK_CONFIG_FILE="$CONFIG_DIR/config/wildduck/default.toml"
    ZONEMTA_CONFIG_FILE="$CONFIG_DIR/config/zonemta/config.toml"
    HARAKA_CONFIG_FILE="$CONFIG_DIR/config/haraka/config.js"
    DKIM_SIGNING_CONFIG="$CONFIG_DIR/config/rspamd/local.d/dkim_signing.conf"

    # --- Modify the copied docker-compose.yml ---

    # Remove wildduck-webmail service block as it's for frontend only
    # This sed command deletes lines from '  wildduck-webmail:' until the next service block or end of file
    sed -i '/^  wildduck-webmail:/,/^  zonemta:/{//!d; /^  wildduck-webmail:/d}' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to remove wildduck-webmail service block"

    # Adjust volumes for remaining services if paths changed (e.g., wildduck, rspamd)
    # The default compose uses ./config for backend, which is correct relative to CONFIG_DIR

    # Update HOSTNAME placeholder in docker-compose.yml
    sed -i "s|HOSTNAME|$HOSTNAME|g" "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to replace HOSTNAME in docker-compose.yml"

    # Add HTTP routing for WildDuck API (backend) without /api prefix
    # Insert new labels after the first 'traefik.enable: true' found under 'wildduck:' service
    sed -i "/^  wildduck:/,/^    labels:/{/^      traefik.enable: true/a \
      - \"traefik.http.routers.wildduck-api-http.rule=Host(\`$HOSTNAME\`)\"\n\
      - \"traefik.http.routers.wildduck-api-http.entrypoints=web\"\n\
      - \"traefik.http.routers.wildduck-api-http.service=wildduck-api-service\"\n\
      - \"traefik.http.routers.wildduck-api-http.middlewares=redirect-to-https@docker\"\n\
      - \"traefik.http.routers.wildduck-api-https.rule=Host(\`$HOSTNAME\`)\"\n\
      - \"traefik.http.routers.wildduck-api-https.entrypoints=websecure\"\n\
      - \"traefik.http.routers.wildduck-api-https.tls=true\"\n\
      - \"traefik.http.routers.wildduck-api-https.service=wildduck-api-service\"\n\
      - \"traefik.http.services.wildduck-api-service.loadbalancer.server.port=8080\"\
    }" "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to add WildDuck API HTTP routing labels"

    # --- Generate and apply secrets ---

    # Generate a random 32-character hex string for WildDuck accessToken
    ACCESS_TOKEN=$(openssl rand -hex 16)
    sed -i "s|accessToken=\"\"|accessToken=\"$ACCESS_TOKEN\"|g" "$WILDUCK_CONFIG_FILE" || error_exit "Failed to set WildDuck accessToken"
    GENERATED_API_URL="https://$HOSTNAME" # API will be directly on hostname now

    # Generate a random 32-character hex string for MongoDB secret
    MONGO_SECRET=$(openssl rand -hex 16)
    sed -i "s|secret = \"\"|secret = \"$MONGO_SECRET\"|g" "$WILDUCK_CONFIG_FILE" || error_exit "Failed to set MongoDB secret"

    # Update domain and hostname in WildDuck config
    sed -i "s|domain = \"example.com\"|domain = \"$MAILDOMAIN\"|g" "$WILDUCK_CONFIG_FILE" || error_exit "Failed to set WildDuck domain"
    sed -i "s|hostname = \"example.com\"|hostname = \"$HOSTNAME\"|g" "$WILDUCK_CONFIG_FILE" || error_exit "Failed to set WildDuck hostname"

    # Generate DKIM keys for rspamd
    echo "Generating DKIM keys..."
    DKIM_SELECTOR="default" # Or prompt for a custom selector
    sudo mkdir -p "$CONFIG_DIR"/config/rspamd/dkim || error_exit "Failed to create DKIM directory"
    sudo rspamadm dkim newkey -s "$DKIM_SELECTOR" -d "$MAILDOMAIN" -k "$CONFIG_DIR"/config/rspamd/dkim/"$DKIM_SELECTOR"."$MAILDOMAIN".key -p "$CONFIG_DIR"/config/rspamd/dkim/"$DKIM_SELECTOR"."$MAILDOMAIN".pub || error_exit "Failed to generate DKIM keys"
    
    # Update DKIM signing config for rspamd
    sed -i "s|domain = \"example.com\"|domain = \"$MAILDOMAIN\"|g" "$DKIM_SIGNING_CONFIG" || error_exit "Failed to set DKIM domain"
    sed -i "s|selector = \"default\"|selector = \"$DKIM_SELECTOR\"|g" "$DKIM_SIGNING_CONFIG" || error_exit "Failed to set DKIM selector"
    sed -i "s|path = \"/var/lib/rspamd/dkim/default.example.com.key\"|path = \"/var/lib/rspamd/dkim/$DKIM_SELECTOR.$MAILDOMAIN.key\"|g" "$DKIM_SIGNING_CONFIG" || error_exit "Failed to set DKIM key path"

    # Update Zone-MTA and Haraka configs (assuming they reference hostname/domain)
    sed -i "s|zone_name = \"example.com\"|zone_name = \"$MAILDOMAIN\"|g" "$ZONEMTA_CONFIG_FILE" || error_exit "Failed to set Zone-MTA zone_name"
    sed -i "s|host = \"mail.example.com\"|host = \"$HOSTNAME\"|g" "$ZONEMTA_CONFIG_FILE" || error_exit "Failed to set Zone-MTA host"
    sed -i "s|\\\"example.com\\\"|\\\"$MAILDOMAIN\\\"|g" "$HARAKA_CONFIG_FILE" || error_exit "Failed to set Haraka domain" # Haraka uses JSON-like config

    echo "Backend configurations applied."
}

# Function to handle SSL certificate setup
function setup_ssl {
    echo "--- Backend SSL Certificate Setup ---"
    echo "Do you wish to set up self-signed certs for development? (y/N) "
    read -r yn
    USE_SELF_SIGNED_CERTS=false
    case $yn in
        [Yy]* ) USE_SELF_SIGNED_CERTS=true;;
        [Nn]* ) USE_SELF_SIGNED_CERTS=false;;
        * ) USE_SELF_SIGNED_CERTS=false;;
    esac

    BACKEND_DOCKER_COMPOSE="$CONFIG_DIR/docker-compose.yml"

    if $USE_SELF_SIGNED_CERTS; then
        echo "Generating self-signed TLS Certs..."
        mkdir -p "$CONFIG_DIR"/certs || error_exit "Failed to create certs directory"
        mkdir -p "$CONFIG_DIR"/dynamic_conf || error_exit "Failed to create dynamic_conf directory" # Needed for file provider

        openssl genrsa -out "$CONFIG_DIR"/certs/rootCA.key 4096 || error_exit "Failed to generate root CA key"
        openssl req -x509 -new -nodes -key "$CONFIG_DIR"/certs/rootCA.key -sha256 -days 3650 -out "$CONFIG_DIR"/certs/rootCA.pem -subj "/C=US/ST=State/L=City/O=Your Organization/CN=Your CA" || error_exit "Failed to generate root CA cert"
        openssl genrsa -out "$CONFIG_DIR"/certs/"$HOSTNAME".key 2048 || error_exit "Failed to generate hostname key"
        openssl req -new -key "$CONFIG_DIR"/certs/"$HOSTNAME".key -out "$CONFIG_DIR"/certs/"$HOSTNAME".csr -subj "/C=US/ST=State/L=City/O=Your Organization/CN=$HOSTNAME" || error_exit "Failed to generate hostname CSR"
        cat > "$CONFIG_DIR"/certs/"$HOSTNAME".ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $HOSTNAME
DNS.2 = *.$MAILDOMAIN
EOF
        openssl x509 -req -in "$CONFIG_DIR"/certs/"$HOSTNAME".csr -CA "$CONFIG_DIR"/certs/rootCA.pem -CAkey "$CONFIG_DIR"/certs/rootCA.key -CAcreateserial -out "$CONFIG_DIR"/certs/"$HOSTNAME".crt -days 825 -sha256 -extfile "$CONFIG_DIR"/certs/"$HOSTNAME".ext || error_exit "Failed to sign hostname cert"
        mv "$CONFIG_DIR"/certs/"$HOSTNAME".crt "$CONFIG_DIR"/certs/"$HOSTNAME".pem || error_exit "Failed to rename cert"
        mv "$CONFIG_DIR"/certs/"$HOSTNAME".key "$CONFIG_DIR"/certs/"$HOSTNAME"-key.pem || error_exit "Failed to rename key"
        echo "Self-signed TLS Certs generated."

        # Traefik configuration for self-signed:
        # Uncomment providers.file lines (they are commented in base compose)
        sed -i 's/^# \( *- "--providers.file=true"\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment providers.file"
        sed -i 's/^# \( *- "--providers.file.directory=\/etc\/traefik\/dynamic_conf"\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment providers.file.directory"
        sed -i 's/^# \( *- "--providers.file.watch=true"\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment providers.file.watch"
        sed -i 's/^# \( *- "--serversTransport.insecureSkipVerify=true"\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment serversTransport.insecureSkipVerify"
        sed -i 's/^# \( *- "--serversTransport.rootCAs=\/etc\/traefik\/certs\/rootCA.pem"\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment serversTransport.rootCAs"

        # Comment out certificatesresolvers.letsencrypt lines (they are uncommented in base compose)
        sed -i 's/^\( *- "--certificatesresolvers.letsencrypt.acme.email=.*\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--certificatesresolvers.letsencrypt.acme.storage=.*\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        
        # Uncomment certs and dynamic_conf volumes
        # These lines are already present in the base docker-compose.yml under Traefik's volumes, but commented out.
        sed -i 's/^# \( *- .\/certs:\/etc\/traefik\/certs\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment certs volume"
        sed -i 's/^# \( *- .\/dynamic_conf:\/etc\/traefik\/dynamic_conf:ro\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment dynamic_conf volume"

        # Change TCP and new HTTP API Traefik labels: use tls: true instead of certresolver
        sed -i 's|^\( *traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt\)|\#\1|g' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to comment imaps certresolver label"
        sed -i 's|^\( *traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt\)|\#\1|g' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to comment pop3s certresolver label"
        sed -i 's|^\( *traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt\)|\#\1|g' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to comment zonemta certresolver label"
        
        # For wildduck HTTP API
        sed -i 's|^\( *traefik.http.routers.wildduck-api-https.tls.certresolver: letsencrypt\)|\#\1|g' "$BACKEND_DOCKER_COMPOSE" || true


    else # Using Let's Encrypt
        echo "Configuring for Let's Encrypt..."
        # Comment out providers.file lines (they are uncommented in base compose)
        sed -i 's/^\( *- "--providers.file=true"\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--providers.file.directory=\/etc\/traefik\/dynamic_conf"\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--providers.file.watch=true"\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--serversTransport.insecureSkipVerify=true"\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- "--serversTransport.rootCAs=\/etc\/traefik\/certs\/rootCA.pem"\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true

        # Uncomment certificatesresolvers.letsencrypt lines (they are commented in base compose)
        # Ensure correct indentation and replacement for ACME_EMAIL
        sed -i "s/^# \( *- \"--certificatesresolvers.letsencrypt.acme.email=ACME_EMAIL\"\)/      - \"--certificatesresolvers.letsencrypt.acme.email=webmaster@$MAILDOMAIN\"/" "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment LE email"
        sed -i 's/^# \( *- "--certificatesresolvers.letsencrypt.acme.storage=.*\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment LE storage"
        sed -i 's/^# \( *- "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"\)/\1/' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment LE tlschallenge"

        # Comment out certs and dynamic_conf volumes
        # These lines are already present in the base docker-compose.yml under Traefik's volumes, but commented out.
        sed -i 's/^\( *- .\/certs:\/etc\/traefik\/certs\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true
        sed -i 's/^\( *- .\/dynamic_conf:\/etc\/traefik\/dynamic_conf:ro\)/# \1/' "$BACKEND_DOCKER_COMPOSE" || true

        # Change TCP and new HTTP API Traefik labels: use certresolver instead of tls: true
        sed -i 's|^# \( *traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt\)|\1|g' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment imaps certresolver label"
        sed -i 's|^# \( *traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt\)|\1|g' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment pop3s certresolver label"
        sed -i 's|^# \( *traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt\)|\1|g' "$BACKEND_DOCKER_COMPOSE" || error_exit "Failed to uncomment zonemta certresolver label"

        # For wildduck HTTP API
        sed -i 's|^# \( *traefik.http.routers.wildduck-api-https.tls.certresolver: letsencrypt\)|\1|g' "$BACKEND_DOCKER_COMPOSE" || true
    fi
}

# Function for MongoDB setup (initial user/replica set)
function setup_mongo {
    echo "--- Setting up MongoDB ---"
    # Assuming initial setup of admin user and replica set if not already done by mongo.sh
    # This part should ideally be in a separate script or handled by Docker entrypoint.
    # For now, we'll just check if mongo.sh exists and source it.
    if [ -f "$SETUP_SCRIPTS_DIR/mongo.sh" ]; then
        echo "Running MongoDB setup script..."
        source "$SETUP_SCRIPTS_DIR/mongo.sh" || error_exit "MongoDB setup script failed."
    else
        echo "MongoDB setup script ($SETUP_SCRIPTS_DIR/mongo.sh) not found. Skipping advanced MongoDB setup."
        echo "Ensure MongoDB is properly configured (e.g., replica set, users) for production use."
    fi
}

# Function to schedule certificate updates
function schedule_cert_updates {
    echo "--- Scheduling Certificate Updates ---"
    # Create an update script that checks for Traefik's generated certs and copies them
    cat > update_certs.sh << EOF
#!/bin/bash
CERT_DIR="$CONFIG_DIR/certs"
ACME_JSON="/data/acme.json" # Path inside Traefik container volume for acme.json
HOSTNAME="$HOSTNAME"

# Ensure directories exist
mkdir -p "\$CERT_DIR" || exit 1

# Check if acme.json exists and is not empty
if [ ! -s "\$ACME_JSON" ]; then
    echo "acme.json not found or empty at \$(date). Skipping certificate update."
    exit 0
fi

# Extract certificate and key from acme.json using jq
# This assumes a single certificate for the HOSTNAME or the first available
CERT=$(jq -r ".[\"acme-v02.api.letsencrypt.org\"].Certificates[] | select(.domain.main == \"\$HOSTNAME\" or .domain.sans[] | contains(\"$HOSTNAME\")) | .certificate" "\$ACME_JSON")
KEY=$(jq -r ".[\"acme-v02.api.letsencrypt.org\"].Certificates[] | select(.domain.main == \"\$HOSTNAME\" or .domain.sans[] | contains(\"$HOSTNAME\")) | .key" "\$ACME_JSON")

if [ -z "\$CERT" ] || [ "\$CERT" == "null" ]; then
    echo "Error: Certificate for \$HOSTNAME not found in acme.json at \$(date)! Make sure Traefik has successfully issued it."
    exit 1
fi

if [ -z "\$KEY" ] || [ "\$KEY" == "null\"" ]; then
    echo "Error: Key for \$HOSTNAME not found in acme.json at \$(date)! Make sure Traefik has successfully issued it."
    exit 1
fi

# Decode and save certificate
echo "\$CERT" | base64 -d > "\$CERT_DIR/\$HOSTNAME.pem" || exit 1

# Decode and save private key
echo "\$KEY" | base64 -d > "\$CERT_DIR/\$HOSTNAME-key.pem" || exit 1

echo "Certificate and key updated successfully at \$(date)"

# Restart affected services if needed (e.g., mail services if they directly use certs)
# For Traefik, this might not be strictly necessary as it reloads, but good for other services.
# sudo docker compose -f "$CONFIG_DIR"/docker-compose.yml restart wildduck zonemta haraka rspamd || true
# Note: For Traefik, it typically reloads certs automatically from /data/acme.json.
# This script is primarily for other services that might need the cert files directly.

EOF
    # Pass the HOSTNAME variable to the script during creation
    sed -i "s/HOSTNAME=\\\"\\\$HOSTNAME\\\"/HOSTNAME=\\\"$HOSTNAME\\\"/" update_certs.sh || error_exit "Failed to inject HOSTNAME into update_certs.sh"

    # Make the script executable
    chmod +x update_certs.sh || error_exit "Failed to make update_certs.sh executable"

    # Add weekly cron job to check for certificate updates
    # Ensure cron job is added for the current user, or adjust for root
    CRON_JOB="0 0 * * 0 $(pwd)/update_certs.sh >> $(pwd)/cert_update.log 2>&1"
    (crontab -l 2>/dev/null || echo "") | grep -v "update_certs.sh" | { cat; echo "$CRON_JOB"; } | crontab - || error_exit "Failed to schedule cron job"

    echo "Weekly certificate update check scheduled for every Sunday at midnight."
    echo "The script will check if Traefik has renewed the certificate and update the files accordingly."
}


# --- Main Script Execution ---

args=("$@")

clean_up
get_domain_and_hostname "${args[@]}"
prepare_config_dirs
apply_backend_configs
setup_ssl # Call the SSL setup function

# Decide whether to perform MongoDB setup based on an argument or interactive prompt
FULL_SETUP=${args[2]:-false} # Get FULL_SETUP from args if provided, else default to false

if [ "$FULL_SETUP" != "full" ]; then
    echo "Do you wish to continue and set up MongoDB (replica set & admin user)? [Y/n] "
    read -r yn
    case $yn in
        [Yy]* ) FULL_SETUP="full";;
        [Nn]* ) echo "MongoDB setup skipped.";;
        * ) FULL_SETUP="full";; # Default to yes
    esac
fi

if [ "$FULL_SETUP" = "full" ]; then
    echo "--- Performing MongoDB setup (initial user/replica set) ---"
    setup_mongo || error_exit "MongoDB setup failed."
    echo "MongoDB setup complete!"
fi

echo "Stopping any existing backend containers..."
# Use -f with the generated docker-compose.yml
sudo docker compose -f "$CONFIG_DIR"/docker-compose.yml down || echo "No existing backend containers to stop."

echo "Deploying backend services..."
# Change to the config directory before running docker compose
cd "$CONFIG_DIR" || error_exit "Failed to change directory to $CONFIG_DIR"
sudo docker compose up -d || error_exit "Failed to deploy backend services"
cd .. # Go back to original directory

echo "Backend deployment complete!"
echo "Traefik dashboard (if enabled and configured) will be on port 80/443."

# Schedule certificate updates only if Let's Encrypt was chosen
if [ "$USE_SELF_SIGNED_CERTS" = false ]; then
    schedule_cert_updates
fi

# --- Print generated credentials ---
echo ""
echo "--- Generated Credentials for Frontend Configuration ---"
echo "WildDuck API URL: $GENERATED_API_URL"
echo "WildDuck API Token: $ACCESS_TOKEN"
echo "WildDuck MongoDB Connection (for backend services): mongodb://wildduck:wildduck@mongo:27017/wildduck?replicaSet=rs0" # This is for internal backend use
echo ""
echo "Please save the API Token and API URL for configuring your frontend (e.g., WildDuck Webmail)."

echo ""
echo "--- DKIM Public Key for DNS ---"
echo "Add the following TXT record to your DNS for domain $MAILDOMAIN:"
sudo cat "$CONFIG_DIR"/config/rspamd/dkim/"$DKIM_SELECTOR"."$MAILDOMAIN".pub || error_exit "Failed to read DKIM public key"
echo "-----------------------------------"

echo "Setup script finished."
