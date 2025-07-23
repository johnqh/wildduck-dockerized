#!/bin/bash

# This script deploys the backend services of the WildDuck mail server.
# It sets up the necessary configurations, handles SSL certificates (self-signed option),
# and starts the Docker containers for the backend components.
# It assumes Traefik handles Let's Encrypt certificates independently.

# Define directories for backend configuration
BACKEND_CONFIG_DIR="./backend-config"
DEFAULT_CONFIG_SOURCE="./default-config"
DYNAMIC_CONF_SOURCE="./dynamic_conf"
BASE_DOCKER_COMPOSE_SOURCE="./docker-compose.yml" # Assuming the base docker-compose.yml is here

# Global variables to store generated secrets for printing at the end
GENERATED_API_TOKEN=""
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
    read -p "Are you sure you want to remove the '$BACKEND_CONFIG_DIR' directory? [Y/n] " yn
    case $yn in
        [Yy]* )
            sudo rm -rf "$BACKEND_CONFIG_DIR" || error_exit "Failed to remove $BACKEND_CONFIG_DIR"
            echo "Clean up complete."
            ;;
        [Nn]* )
            echo "No files and folders removed. Continuing with deployment..."
            ;;
        * )
            sudo rm -rf "$BACKEND_CONFIG_DIR" || error_exit "Failed to remove $BACKEND_CONFIG_DIR"
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
        read -p "Specify the MAILDOMAIN for your backend server (e.g., example.com): " MAILDOMAIN
        read -p "Perfect! The email domain is: $MAILDOMAIN. Do you wish to also specify the hostname? [y/N] " yn
        case $yn in
            [Yy]* ) read -p "Hostname of the machine (e.g., mail.example.com): " HOSTNAME;;
            [Nn]* ) echo "No hostname provided. Will use domain as hostname"; HOSTNAME=$MAILDOMAIN;;
            * ) echo "No hostname provided. Will use domain as hostname"; HOSTNAME=$MAILDOMAIN;;
        esac
        echo -e "DOMAINNAME: $MAILDOMAIN, HOSTNAME: $HOSTNAME"
    fi

    if [ -z "$MAILDOMAIN" ] || [ -z "$HOSTNAME" ]; then
        error_exit "Mail domain or hostname cannot be empty."
    fi
}

# Function to prepare backend configuration directories and copy docker-compose
function prepare_config_dirs {
    echo "Preparing backend configuration directories..."
    mkdir -p "$BACKEND_CONFIG_DIR" || error_exit "Failed to create $BACKEND_CONFIG_DIR"

    # Copy default configurations
    cp -r "$DEFAULT_CONFIG_SOURCE"/wildduck "$BACKEND_CONFIG_DIR"/wildduck || error_exit "Failed to copy wildduck config"
    cp -r "$DEFAULT_CONFIG_SOURCE"/zone-mta "$BACKEND_CONFIG_DIR"/zone-mta || error_exit "Failed to copy zone-mta config"
    cp -r "$DEFAULT_CONFIG_SOURCE"/haraka "$BACKEND_CONFIG_DIR"/haraka || error_exit "Failed to copy haraka config"
    cp -r "$DEFAULT_CONFIG_SOURCE"/rspamd "$BACKEND_CONFIG_DIR"/rspamd || error_exit "Failed to copy rspamd config"
    cp -r "$DYNAMIC_CONF_SOURCE" "$BACKEND_CONFIG_DIR" || error_exit "Failed to copy dynamic_conf"

    # No need to copy Redis config for backend deployment as it's not managed here.

    # Copy the base docker-compose.yml into the backend config directory
    if [ ! -f "$BASE_DOCKER_COMPOSE_SOURCE" ]; then
        error_exit "Base docker-compose.yml not found at $BASE_DOCKER_COMPOSE_SOURCE. Please ensure it's in the same directory as this script."
    fi
    cp "$BASE_DOCKER_COMPOSE_SOURCE" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to copy base docker-compose.yml"

    echo "Configuration directories and docker-compose.yml prepared."
}

# Function to apply hostname and secrets to backend configurations
function apply_backend_configs {
    echo "Applying hostname and secrets to backend configurations..."

    # Modify the copied docker-compose.yml
    # Remove Redis port exposure (if it was added by previous versions of the script)
    sed -i '/ports:\n      - "6379:6379" # Expose Redis server/d' "$BACKEND_CONFIG_DIR"/docker-compose.yml || true # Use true to prevent exit if line not found

    # Remove volume mount for redis.conf (if it was added by previous versions of the script)
    sed -i '/- .\/redis\/redis.conf:\/usr\/local\/etc\/redis\/redis.conf/d' "$BACKEND_CONFIG_DIR"/docker-compose.yml || true # Use true to prevent exit if line not found

    # Replace HOSTNAME placeholder in docker-compose.yml
    sed -i "s|HOSTNAME|$HOSTNAME|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to replace HOSTNAME in docker-compose.yml"
    # Adjust volume paths for copied configs
    sed -i "s|./config/wildduck|./wildduck|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust wildduck volume path"
    sed -i "s|./config/wildduck-webmail|./wildduck-webmail|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust webmail volume path"
    sed -i "s|./config/zone-mta|./zone-mta|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust zone-mta volume path"
    sed -i "s|./config/haraka|./haraka|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust haraka volume path"
    sed -i "s|./config/rspamd|./rspamd|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust rspamd volume path"
    sed -i "s|./dynamic_conf|./dynamic_conf|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust dynamic_conf volume path"
    sed -i "s|./certs:/etc/traefik/certs # Mount your certs directory|./certs:/etc/traefik/certs # Mount your certs directory|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust certs volume path"


    # Remove wildduck-webmail service from backend docker-compose.yml
    # This assumes wildduck-webmail is a distinct block in the docker-compose.yml
    sed -i '/wildduck-webmail:/,/^$/d' "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove wildduck-webmail service from docker-compose.yml"


    # Zone-MTA
    sed -i "s/name=\"example.com\"/name=\"$HOSTNAME\"/" "$BACKEND_CONFIG_DIR"/zone-mta/pools.toml || error_exit "Failed to update Zone-MTA pools.toml"
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$BACKEND_CONFIG_DIR"/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml hostname"
    sed -i "s/rewriteDomain=\"email.example.com\"/rewriteDomain=\"$MAILDOMAIN\"/" "$BACKEND_CONFIG_DIR"/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml rewriteDomain"

    # Wildduck
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$BACKEND_CONFIG_DIR"/wildduck/imap.toml || error_exit "Failed to update Wildduck imap.toml"
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$BACKEND_CONFIG_DIR"/wildduck/pop3.toml || error_exit "Failed to update Wildduck pop3.toml"
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$BACKEND_CONFIG_DIR"/wildduck/default.toml || error_exit "Failed to update Wildduck default.toml hostname"
    sed -i "s/rpId=\"email.example.com\"/rpId=\"$HOSTNAME\"/" "$BACKEND_CONFIG_DIR"/wildduck/default.toml || error_exit "Failed to update Wildduck default.toml rpId"
    sed -i "s/emailDomain=\"email.example.com\"/emailDomain=\"$MAILDOMAIN\"/" "$BACKEND_CONFIG_DIR"/wildduck/default.toml || error_exit "Failed to update Wildduck default.toml emailDomain"

    # Generate secrets
    SRS_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)
    ZONEMTA_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)
    DKIM_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)
    GENERATED_API_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30) # Store for printing
    HMAC_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)

    # Apply secrets
    sed -i "s/secret=\"super secret value\"/secret=\"$ZONEMTA_SECRET\"/" "$BACKEND_CONFIG_DIR"/zone-mta/plugins/loop-breaker.toml || error_exit "Failed to update Zone-MTA loop-breaker.toml"
    sed -i "s/secret=\"secret value\"/secret=\"$SRS_SECRET\"/" "$BACKEND_CONFIG_DIR"/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml secret"
    sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" "$BACKEND_CONFIG_DIR"/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml DKIM secret"

    sed -i "s/#loopSecret=\"secret value\"/loopSecret=\"$SRS_SECRET\"/" "$BACKEND_CONFIG_DIR"/wildduck/sender.toml || error_exit "Failed to update Wildduck sender.toml"
    sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" "$BACKEND_CONFIG_DIR"/wildduck/dkim.toml || error_exit "Failed to update Wildduck dkim.toml"
    sed -i "s/accessToken=\"somesecretvalue\"/accessToken=\"$GENERATED_API_TOKEN\"/" "$BACKEND_CONFIG_DIR"/wildduck/api.toml || error_exit "Failed to update Wildduck api.toml accessToken"
    sed -i "s/secret=\"a secret cat\"/secret=\"$HMAC_SECRET\"/" "$BACKEND_CONFIG_DIR"/wildduck/api.toml || error_exit "Failed to update Wildduck api.toml secret"
    sed -i "s/\"domainadmin@example.com\"/\"domainadmin@$MAILDOMAIN\"/" "$BACKEND_CONFIG_DIR"/wildduck/acme.toml || error_exit "Failed to update Wildduck acme.toml email"
    sed -i "s/\"https:\/\/wildduck.email\"/\"https:\/\/$MAILDOMAIN\"/" "$BACKEND_CONFIG_DIR"/wildduck/acme.toml || error_exit "Failed to update Wildduck acme.toml URL"

    sed -i "s/#loopSecret: \"secret value\"/loopSecret: \"$SRS_SECRET\"/" "$BACKEND_CONFIG_DIR"/haraka/wildduck.yaml || error_exit "Failed to update Haraka wildduck.yaml loopSecret"
    sed -i "s/secret: \"secret value\"/secret: \"$SRS_SECRET\"/" "$BACKEND_CONFIG_DIR"/haraka/wildduck.yaml || error_exit "Failed to update Haraka wildduck.yaml secret"

    # --- Removed Redis Password Configuration ---
    # The Redis password generation and setting logic has been removed as per request.

    echo "Backend configurations applied."
}

# Function to handle SSL certificate setup
function setup_ssl {
    echo "--- SSL Certificate Setup ---"
    USE_SELF_SIGNED_CERTS=false
    read -p "Do you wish to set up self-signed certs for development? (y/N) " yn
    case $yn in
        [Yy]* ) USE_SELF_SIGNED_CERTS=true;;
        [Nn]* ) USE_SELF_SIGNED_CERTS=false;;
        * ) USE_SELF_SIGNED_CERTS=false;;
    esac

    if $USE_SELF_SIGNED_CERTS; then
        echo "Generating self-signed TLS Certs..."
        mkdir -p "$BACKEND_CONFIG_DIR"/certs || error_exit "Failed to create certs directory"

        openssl genrsa -out "$BACKEND_CONFIG_DIR"/certs/rootCA.key 4096 || error_exit "Failed to generate root CA key"
        openssl req -x509 -new -nodes -key "$BACKEND_CONFIG_DIR"/certs/rootCA.key -sha256 -days 3650 -out "$BACKEND_CONFIG_DIR"/certs/rootCA.pem -subj "/C=US/ST=State/L=City/O=Your Organization/CN=Your CA" || error_exit "Failed to generate root CA cert"
        openssl genrsa -out "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".key 2048 || error_exit "Failed to generate hostname key"
        openssl req -new -key "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".key -out "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".csr -subj "/C=US/ST=State/L=City/O=Your Organization/CN=$HOSTNAME" || error_exit "Failed to generate hostname CSR"
        cat > "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $HOSTNAME
DNS.2 = *.$HOSTNAME
EOF
        openssl x509 -req -in "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".csr -CA "$BACKEND_CONFIG_DIR"/certs/rootCA.pem -CAkey "$BACKEND_CONFIG_DIR"/certs/rootCA.key -CAcreateserial -out "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".crt -days 825 -sha256 -extfile "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".ext || error_exit "Failed to sign hostname cert"
        mv "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".crt "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".pem || error_exit "Failed to rename cert"
        mv "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME".key "$BACKEND_CONFIG_DIR"/certs/"$HOSTNAME"-key.pem || error_exit "Failed to rename key"
        echo "Self-signed TLS Certs generated."
    else
        echo "Assuming Traefik will manage Let's Encrypt certificates independently."
        echo "Ensure Traefik's configuration in your docker-compose.yml (or dynamic config) is set up for Let's Encrypt."
        # No changes to docker-compose.yml are made here for Let's Encrypt,
        # as per the request that Traefik manages it on its own.
        # Haraka will use the mounted certs directory, which Traefik is expected to populate.
    fi

    # Haraka certs settings (these paths will be used regardless of self-signed or LE)
    sed -i "s|./certs/HOSTNAME-key.pem|./certs/$HOSTNAME-key.pem|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update Haraka key path in docker-compose.yml"
    sed -i "s|./certs/HOSTNAME.pem|./certs/$HOSTNAME.pem|g" "$BACKEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update Haraka cert path in docker-compose.yml"
}

# --- Main Script Execution ---

args=("$@")

clean_up
get_domain_and_hostname "${args[@]}"
prepare_config_dirs
apply_backend_configs
setup_ssl

echo "Stopping any existing backend containers..."
sudo docker compose -f "$BACKEND_CONFIG_DIR"/docker-compose.yml down || echo "No existing backend containers to stop."

echo "Deploying backend services..."
cd "$BACKEND_CONFIG_DIR" || error_exit "Failed to change directory to $BACKEND_CONFIG_DIR"
sudo docker compose up -d || error_exit "Failed to deploy backend services"
cd .. # Go back to original directory

echo "Backend deployment complete!"
echo "Traefik dashboard (if enabled and configured) will be on port 80/443."

# --- Print generated credentials ---
echo ""
echo "--- Generated Credentials for Frontend Configuration ---"
GENERATED_API_URL="https://$HOSTNAME/api"

echo "WildDuck API URL: $GENERATED_API_URL"
echo "WildDuck API Token: $GENERATED_API_TOKEN"
echo "------------------------------------------------------"
