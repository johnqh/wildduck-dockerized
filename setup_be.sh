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
    read yn
    case $yn in
        [Yy]* )
            sudo rm -rf "$CONFIG_DIR" || error_exit "Failed to remove $CONFIG_DIR"
            sudo rm -rf ./acme.json || echo "acme.json not found, skipping removal." # Allow skipping if not exists
            sudo rm -rf update_certs.sh || echo "update_certs.sh not found, skipping removal." # Allow skipping if not exists
            echo "Clean up complete."
            ;;
        [Nn]* )
            echo "No files and folders removed. Continuing with deployment..."
            ;;
        * )
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
        echo "Specify the MAILDOMAIN for your backend server (e.g., example.com): "
        read MAILDOMAIN
        echo "Perfect! The email domain is: $MAILDOMAIN. Do you wish to also specify the hostname? [y/N] "
        read yn
        case $yn in
            [Yy]* )
                echo "Hostname of the machine (e.g., mail.example.com): "
                read HOSTNAME
                ;;
            [Nn]* )
                echo "No hostname provided. Will use domain as hostname"
                HOSTNAME=$MAILDOMAIN
                ;;
            * )
                echo "No hostname provided. Will use domain as hostname"
                HOSTNAME=$MAILDOMAIN
                ;;
        esac
        echo -e "DOMAINNAME: $MAILDOMAIN, HOSTNAME: $HOSTNAME"
    fi

    if [ -z "$MAILDOMAIN" ] || [ -z "$HOSTNAME" ]; then
        error_exit "Mail domain or hostname cannot be empty."
    fi

    # Prompt for INDEXER_BASE_URL
    echo "Enter the INDEXER_BASE_URL for the WildDuck project: "
    read INDEXER_BASE_URL
    if [ -z "$INDEXER_BASE_URL" ]; then
        echo "Warning: INDEXER_BASE_URL is empty. This may cause issues with the WildDuck indexer."
    fi

    # Export the variable for current session
    export INDEXER_BASE_URL="$INDEXER_BASE_URL"

    # Save to .env file for persistence
    if [ ! -f .env ]; then
        touch .env
    fi

    # Check if INDEXER_BASE_URL already exists in .env and update it, or add it
    if grep -q "^INDEXER_BASE_URL=" .env; then
        sed -i "s|^INDEXER_BASE_URL=.*|INDEXER_BASE_URL=$INDEXER_BASE_URL|" .env
    else
        echo "INDEXER_BASE_URL=$INDEXER_BASE_URL" >> .env
    fi

    echo "INDEXER_BASE_URL has been set to: $INDEXER_BASE_URL"
}

# Function to prepare backend configuration directories and copy docker-compose
function prepare_config_dirs {
    echo "Preparing backend configuration directories..."
    # Create the main backend config directory and the nested config-generated directory
    mkdir -p "$CONFIG_DIR"/config-generated || error_exit "Failed to create $CONFIG_DIR/config-generated"

    # Copy default configurations into the nested config-generated directory
    cp -r "$DEFAULT_CONFIG_SOURCE"/wildduck "$CONFIG_DIR"/config-generated/wildduck || error_exit "Failed to copy wildduck config"
    cp -r "$DEFAULT_CONFIG_SOURCE"/zone-mta "$CONFIG_DIR"/config-generated/zone-mta || error_exit "Failed to copy zone-mta config"
    cp -r "$DEFAULT_CONFIG_SOURCE"/haraka "$CONFIG_DIR"/config-generated/haraka || error_exit "Failed to copy haraka config"
    cp -r "$DEFAULT_CONFIG_SOURCE"/rspamd "$CONFIG_DIR"/config-generated/rspamd || error_exit "Failed to copy rspamd config"

    # dynamic_conf is usually directly under traefik's config, not nested like service configs
    cp -r "$DYNAMIC_CONF_SOURCE" "$CONFIG_DIR"/dynamic_conf || error_exit "Failed to copy dynamic_conf"

    # Copy the base docker-compose.yml into the main backend config directory
    if [ ! -f "$BASE_DOCKER_COMPOSE_SOURCE" ]; then
        error_exit "Base docker-compose.yml not found at $BASE_DOCKER_COMPOSE_SOURCE. Please ensure it's in the same directory as this script."
    fi
    cp "$BASE_DOCKER_COMPOSE_SOURCE" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to copy base docker-compose.yml"

    echo "Configuration directories and docker-compose.yml prepared."
}

# Function to apply hostname and secrets to backend configurations
function apply_backend_configs {
    echo "Applying hostname and secrets to backend configurations..."

    # Modify the copied docker-compose.yml
    # Remove Redis port exposure (if it was added by previous versions of the script)
    sed -i '/ports:\n      - "6379:6379" # Expose Redis server/d' "$CONFIG_DIR"/docker-compose.yml || true # Use true to prevent exit if line not found

    # Remove volume mount for redis.conf (if it was added by previous versions of the script)
    sed -i '/- .\/redis\/redis.conf:\/usr\/local\/etc\/redis\/redis.conf/d' "$CONFIG_DIR"/docker-compose.yml || true # Use true to prevent exit if line not found

    # Replace HOSTNAME placeholder in docker-compose.yml
    sed -i "s|HOSTNAME|$HOSTNAME|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to replace HOSTNAME in docker-compose.yml"

    # --- START OF MODIFICATION ---
    # Modify Traefik routing label for wildduck service to remove PathPrefix('/api')
    # This ensures all requests to HOSTNAME go to the wildduck container.
    sed -i "s|traefik.http.routers.wildduck.rule=Host(\`$HOSTNAME\`)\ \&\&\ PathPrefix(\`/api\`)|traefik.http.routers.wildduck.rule=Host(\`$HOSTNAME\`)|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update WildDuck Traefik rule"
    # --- END OF MODIFICATION ---
    
    echo "Fixing wildduck-api-path rule: disabling PathPrefix(/api), enabling plain Host(\`$HOSTNAME\`) match..."


# Comment the line with PathPrefix(`/api`)
    sed -i "/traefik.http.routers.wildduck-api-path.rule: Host(\`$HOSTNAME\`) && PathPrefix(\`\/api\`)/s/^/      # /" "$CONFIG_DIR/docker-compose.yml"

# Uncomment the simpler Host-only rule if it's commented
    sed -i "s/^      # traefik.http.routers.wildduck-api-path.rule: Host(\`$HOSTNAME\`)/      traefik.http.routers.wildduck-api-path.rule: Host(\`$HOSTNAME\`)/" "$CONFIG_DIR/docker-compose.yml"
  
    # comment strippedPrefix rule
    sed -i "/traefik.http.routers.wildduck-api-path.middlewares: wildduck-api-stripprefix@docker/s/^/      # /" "$CONFIG_DIR/docker-compose.yml"
    sed -i "/traefik.http.middlewares.wildduck-api-stripprefix.stripprefix.prefixes: \/api/s/^/      # /" "$CONFIG_DIR/docker-compose.yml"


    # Adjust volume paths for copied configs to point to the nested config-generated directory
    sed -i "s|./config/wildduck|./config-generated/wildduck|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust wildduck volume path"
    sed -i "s|./config/wildduck-webmail|./config-generated/wildduck-webmail|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust webmail volume path"
    sed -i "s|./config/zone-mta|./config-generated/zone-mta|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust zone-mta volume path"
    sed -i "s|./config/haraka|./config-generated/haraka|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust haraka volume path"
    sed -i "s|./config/rspamd|./config-generated/rspamd|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust rspamd volume path"
    # dynamic_conf and certs are not under config-generated, so their paths remain relative to CONFIG_DIR
    sed -i "s|./dynamic_conf|./dynamic_conf|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust dynamic_conf volume path"
    sed -i "s|./certs:/etc/traefik/certs # Mount your certs directory|./certs:/etc/traefik/certs # Mount your certs directory|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust certs volume path"


    # Remove wildduck-webmail service from backend docker-compose.yml
    # This assumes wildduck-webmail is a distinct block in the docker-compose.yml
    sed -i '/wildduck-webmail:/,/^$/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove wildduck-webmail service from docker-compose.yml"


    # Zone-MTA
    sed -i "s/name=\"example.com\"/name=\"$HOSTNAME\"/" "$CONFIG_DIR"/config-generated/zone-mta/pools.toml || error_exit "Failed to update Zone-MTA pools.toml"
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$CONFIG_DIR"/config-generated/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml hostname"
    sed -i "s/rewriteDomain=\"email.example.com\"/rewriteDomain=\"$MAILDOMAIN\"/" "$CONFIG_DIR"/config-generated/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml rewriteDomain"

    # Wildduck
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$CONFIG_DIR"/config-generated/wildduck/imap.toml || error_exit "Failed to update Wildduck imap.toml"
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$CONFIG_DIR"/config-generated/wildduck/pop3.toml || error_exit "Failed to update Wildduck pop3.toml"
    sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" "$CONFIG_DIR"/config-generated/wildduck/default.toml || error_exit "Failed to update Wildduck default.toml hostname"
    sed -i "s/rpId=\"email.example.com\"/rpId=\"$HOSTNAME\"/" "$CONFIG_DIR"/config-generated/wildduck/default.toml || error_exit "Failed to update Wildduck default.toml rpId"
    sed -i "s/emailDomain=\"email.example.com\"/emailDomain=\"$MAILDOMAIN\"/" "$CONFIG_DIR"/config-generated/wildduck/default.toml || error_exit "Failed to update Wildduck default.toml emailDomain"

    # Generate secrets
    SRS_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)
    ZONEMTA_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)
    DKIM_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)
    ACCESS_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30) # Store for printing
    HMAC_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)

    # Apply secrets
    sed -i "s/secret=\"super secret value\"/secret=\"$ZONEMTA_SECRET\"/" "$CONFIG_DIR"/config-generated/zone-mta/plugins/loop-breaker.toml || error_exit "Failed to update Zone-MTA loop-breaker.toml"
    sed -i "s/secret=\"secret value\"/secret=\"$SRS_SECRET\"/" "$CONFIG_DIR"/config-generated/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml secret"
    sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" "$CONFIG_DIR"/config-generated/zone-mta/plugins/wildduck.toml || error_exit "Failed to update Zone-MTA wildduck.toml DKIM secret"

    sed -i "s/#loopSecret=\"secret value\"/loopSecret=\"$SRS_SECRET\"/" "$CONFIG_DIR"/config-generated/wildduck/sender.toml || error_exit "Failed to update Wildduck sender.toml"
    sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" "$CONFIG_DIR"/config-generated/wildduck/dkim.toml || error_exit "Failed to update Wildduck dkim.toml"
    sed -i "s/accessToken=\"somesecretvalue\"/accessToken=\"$ACCESS_TOKEN\"/" "$CONFIG_DIR"/config-generated/wildduck/api.toml || error_exit "Failed to update Wildduck api.toml accessToken"
    sed -i "s/secret=\"a secret cat\"/secret=\"$HMAC_SECRET\"/" "$CONFIG_DIR"/config-generated/wildduck/api.toml || error_exit "Failed to update Wildduck api.toml secret"
    sed -i "s/\"domainadmin@example.com\"/\"domainadmin@$MAILDOMAIN\"/" "$CONFIG_DIR"/config-generated/wildduck/acme.toml || error_exit "Failed to update Wildduck acme.toml email"
    sed -i "s/\"https:\/\/wildduck.email\"/\"https:\/\/$MAILDOMAIN\"/" "$CONFIG_DIR"/config-generated/wildduck/acme.toml || error_exit "Failed to update Wildduck acme.toml URL"

    sed -i "s/#loopSecret: \"secret value\"/loopSecret: \"$SRS_SECRET\"/" "$CONFIG_DIR"/config-generated/haraka/wildduck.yaml || error_exit "Failed to update Haraka wildduck.yaml loopSecret"
    sed -i "s/secret: \"secret value\"/secret: \"$SRS_SECRET\"/" "$CONFIG_DIR"/config-generated/haraka/wildduck.yaml || error_exit "Failed to update Haraka wildduck.yaml secret"

    echo "Backend configurations applied."
}

# Function to handle SSL certificate setup
function setup_ssl {
    echo "--- SSL Certificate Setup ---"
    echo "Do you wish to set up self-signed certs for development? (y/N) "
    read yn
    USE_SELF_SIGNED_CERTS=false
    case $yn in
        [Yy]* ) USE_SELF_SIGNED_CERTS=true;;
        [Nn]* ) USE_SELF_SIGNED_CERTS=false;;
        * ) USE_SELF_SIGNED_CERTS=false;;
    esac

    if $USE_SELF_SIGNED_CERTS; then
        echo "Generating self-signed TLS Certs..."
        mkdir -p "$CONFIG_DIR"/certs || error_exit "Failed to create certs directory"

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
DNS.2 = *.$HOSTNAME
EOF
        openssl x509 -req -in "$CONFIG_DIR"/certs/"$HOSTNAME".csr -CA "$CONFIG_DIR"/certs/rootCA.pem -CAkey "$CONFIG_DIR"/certs/rootCA.key -CAcreateserial -out "$CONFIG_DIR"/certs/"$HOSTNAME".crt -days 825 -sha256 -extfile "$CONFIG_DIR"/certs/"$HOSTNAME".ext || error_exit "Failed to sign hostname cert"
        mv "$CONFIG_DIR"/certs/"$HOSTNAME".crt "$CONFIG_DIR"/certs/"$HOSTNAME".pem || error_exit "Failed to rename cert"
        mv "$CONFIG_DIR"/certs/"$HOSTNAME".key "$CONFIG_DIR"/certs/"$HOSTNAME"-key.pem || error_exit "Failed to rename key"
        echo "Self-signed TLS Certs generated."
    else
        echo "Configuring for Let's Encrypt and getting certs for Haraka from Traefik..."
        # Uncomment Let's Encrypt lines in docker-compose.yml
        sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.email=ACME_EMAIL\"|- \"--certificatesresolvers.letsencrypt.acme.email=domainadmin@$MAILDOMAIN\"|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update LE email"
        sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|- \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update LE storage"
        sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|- \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update LE tlschallenge"

        # Uncomment certresolver lines for Traefik TCP routers
        sed -i "s|# traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt|traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to uncomment zonemta certresolver"
        sed -i "s|# traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt|traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to uncomment pop3s certresolver"
        sed -i "s|# traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt|traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to uncomment imaps certresolver"

        # Remove explicit 'tls: true' lines as certresolver implies TLS
        sed -i "/traefik.tcp.routers.zonemta.tls: true/d" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove zonemta tls: true"
        sed -i "/traefik.tcp.routers.wildduck-pop3s.tls: true/d" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove pop3s tls: true"
        sed -i "/traefik.tcp.routers.wildduck-imaps.tls: true/d" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove imaps tls: true"

        # Remove file provider related lines if using Let's Encrypt
        sed -i '/- "--providers.file=true"/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove providers.file=true"
        sed -i '/- "--providers.file.directory=\/etc\/traefik\/dynamic_conf"/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove providers.file.directory"
        sed -i '/- "--providers.file.watch=true"/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove providers.file.watch"
        sed -i '/- "--serversTransport.insecureSkipVerify=true"/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove insecureSkipVerify"
        sed -i '/- "--serversTransport.rootCAs=\/etc\/traefik\/certs\/rootCA.pem"/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove rootCAs"
        sed -i '/- \.\/certs:\/etc\/traefik\/certs.*# Mount your certs directory/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove certs mount"
        sed -i '/- \.\/dynamic_conf:\/etc\/traefik\/dynamic_conf:ro/d' "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to remove dynamic_conf mount"

        echo "Let's Encrypt configuration applied."

        echo "Getting certs for Haraka from Traefik..."
        # Start Traefik and Wildduck to obtain certs
        cd "$CONFIG_DIR" || error_exit "Failed to change directory to $CONFIG_DIR"
        sudo docker compose up traefik wildduck -d || error_exit "Failed to start Traefik and Wildduck"
        cd .. # Go back to original directory

        echo "Waiting for Traefik to obtain certificate for $HOSTNAME..."
        TIMEOUT=120 # Increased timeout for cert acquisition
        INTERVAL=5
        ELAPSED=0
        CERT_READY=false

        while [ $ELAPSED -lt $TIMEOUT ]; do
            CONTAINER_ID=$(sudo docker ps --filter "name=traefik" --format "{{.ID}}")
            if [ -z "$CONTAINER_ID" ]; then
                echo "Traefik container not found. Waiting for it to start..."
                sleep $INTERVAL
                ELAPSED=$((ELAPSED + INTERVAL))
                continue
            fi

            sudo docker cp "$CONTAINER_ID":/data/acme.json ./acme.json 2>/dev/null
            sudo chmod a+r ./acme.json



            if [ -f "./acme.json" ] && sudo jq -e --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain)' ./acme.json >/dev/null; then
                CERT_READY=true
                echo "Certificate found for $HOSTNAME."
                break
            fi

            echo "Waiting... ($ELAPSED/${TIMEOUT}s)"
            sleep $INTERVAL
            ELAPSED=$((ELAPSED + INTERVAL))
        done

        if [ "$CERT_READY" = false ]; then
            error_exit "Certificate for $HOSTNAME not found in acme.json after $TIMEOUT seconds. Please check Traefik logs."
        fi

        mkdir -p "$CONFIG_DIR"/certs/ || error_exit "Failed to create backend certs directory"
        CERT_FILE="$CONFIG_DIR"/certs/"$HOSTNAME".pem
        KEY_FILE="$CONFIG_DIR"/certs/"$HOSTNAME"-key.pem

        CERT=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .certificate' acme.json) || error_exit "Failed to extract certificate"
        KEY=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .key' acme.json) || error_exit "Failed to extract key"

        if [ -z "$CERT" ] || [ "$CERT" == "null" ]; then
            error_exit "Error: Certificate for $HOSTNAME not found after extraction!"
        fi
        if [ -z "$KEY" ] || [ "$KEY" == "null" ]; then
            error_exit "Error: Key for \$HOSTNAME not found after extraction!"
        fi

        echo "$CERT" | base64 -d > "$CERT_FILE" || error_exit "Failed to decode and save certificate"
        echo "$KEY" | base64 -d > "$KEY_FILE" || error_exit "Failed to decode and save private key"
        echo "Haraka certificates updated."

        # Create update_certs.sh script
        cat > update_certs.sh << EOF
#!/bin/bash

# This script is generated by deploy_backend.sh to periodically update SSL certificates
# obtained via Let's Encrypt for Haraka.

HOSTNAME="$HOSTNAME" # This variable will be replaced by the deploy_backend.sh script
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ACME_PATH="\$SCRIPT_DIR/acme.json"
NEW_ACME_PATH="\$SCRIPT_DIR/acme.json.new"
CERT_FILE="\$SCRIPT_DIR/$CONFIG_DIR/certs/\$HOSTNAME.pem"
KEY_FILE="\$SCRIPT_DIR/$CONFIG_DIR/certs/\$HOSTNAME-key.pem"

echo "Checking for certificate updates for \$HOSTNAME at \$(date)..."

CONTAINER_ID=\$(sudo docker ps --filter "name=traefik" --format "{{.ID}}")

if [ -z "\$CONTAINER_ID" ]; then
    echo "Traefik container not running. Attempting to start it..."
    cd "\$SCRIPT_DIR/$CONFIG_DIR" || error_exit "Failed to change directory to $CONFIG_DIR"
    sudo docker compose up traefik -d || error_exit "Failed to start Traefik"
    cd "\$SCRIPT_DIR" || error_exit "Failed to return to script directory"
    sleep 5 # Give Traefik some time to start
    CONTAINER_ID=\$(sudo docker ps --filter "name=traefik" --format "{{.ID}}")
    if [ -z "\$CONTAINER_ID" ]; then
        echo "Failed to start Traefik container. Exiting update check."
        exit 1
    fi
fi

# Copy the acme.json file from Traefik container
sudo docker cp "\$CONTAINER_ID":/data/acme.json "\$NEW_ACME_PATH" 2>/dev/null

# Check if acme.json has changed
if [ -f "\$ACME_PATH" ] && diff -q "\$ACME_PATH" "\$NEW_ACME_PATH" >/dev/null; then
    echo "No changes in certificates detected."
    rm "\$NEW_ACME_PATH"
    exit 0
fi

# Replace the old acme.json with the new one
mv "\$NEW_ACME_PATH" "\$ACME_PATH" || error_exit "Failed to replace acme.json"

echo "Certificate changes detected. Updating certificate files..."

# Extract the certificate
CERT=\$(sudo jq -r --arg domain "\$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == \$domain) | .certificate' "\$ACME_PATH")
# Extract the private key
KEY=\$(sudo jq -r --arg domain "\$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == \$domain) | .key' "\$ACME_PATH")

if [ -z "\$CERT" ] || [ "\$CERT" == "null" ]; then
    echo "Error: Certificate for \$HOSTNAME not found in new acme.json!"
    exit 1
fi
if [ -z "\$KEY" ] || [ "\$KEY" == "null" ]; then
    echo "Error: Key for \$HOSTNAME not found in new acme.json!"
    exit 1
fi

mkdir -p "\$(dirname "\$CERT_FILE")" || error_exit "Failed to create certs directory for update"

echo "\$CERT" | base64 -d > "\$CERT_FILE" || error_exit "Failed to decode and save certificate during update"
echo "\$KEY" | base64 -d > "\$KEY_FILE" || error_exit "Failed to decode and save private key during update"

echo "Certificate and key updated successfully at \$(date)"

# No need to stop the container if it was already running, Haraka will pick up changes
EOF
        chmod +x update_certs.sh || error_exit "Failed to make update_certs.sh executable"
        sed -i "s/HOSTNAME=\"\$HOSTNAME\"/HOSTNAME=\"$HOSTNAME\"/" update_certs.sh || error_exit "Failed to inject HOSTNAME into update_certs.sh"

        # Add weekly cron job
        CRON_JOB="0 0 * * 0 $(pwd)/update_certs.sh >> $(pwd)/cert_update.log 2>&1"
        (crontab -l 2>/dev/null || echo "") | grep -v "update_certs.sh" | { cat; echo "$CRON_JOB"; } | crontab - || error_exit "Failed to add cron job"
        echo "Weekly certificate update check scheduled for every Sunday at midnight."
    fi

    # Haraka certs settings (these paths will be used regardless of self-signed or LE)
    sed -i "s|./certs/HOSTNAME-key.pem|./certs/$HOSTNAME-key.pem|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update Haraka key path in docker-compose.yml"
    sed -i "s|./certs/HOSTNAME.pem|./certs/$HOSTNAME.pem|g" "$CONFIG_DIR"/docker-compose.yml || error_exit "Failed to update Haraka cert path in docker-compose.yml"
}

# --- Main Script Execution ---

args=("$@")

clean_up

source "./setup-scripts/deps_setup.sh"
get_domain_and_hostname "${args[@]}"
prepare_config_dirs
apply_backend_configs
setup_ssl



# --- Re-incorporate MongoDB setup ---
echo "--- Performing MongoDB setup ---"
if [ ! -f "$SETUP_SCRIPTS_DIR/mongo.sh" ]; then
    error_exit "MongoDB setup script not found at $SETUP_SCRIPTS_DIR/mongo.sh. Please ensure it exists."
fi
source "$SETUP_SCRIPTS_DIR/mongo.sh" "$CONFIG_DIR" "$MAILDOMAIN" "$HOSTNAME" || error_exit "MongoDB setup failed."




echo "Stopping any existing backend containers..."
sudo docker stop $(docker ps -q)  || echo "No existing backend containers to stop."

echo "Deploying backend services..."
cd "$CONFIG_DIR" || error_exit "Failed to change directory to $CONFIG_DIR"
sudo docker compose up -d || error_exit "Failed to deploy backend services"
cd .. # Go back to original directory


# --- Re-incorporate DNS setup ---
# Assuming FULL_SETUP is a variable that might be passed or prompted for
FULL_SETUP=${args[2]:-false} # Get FULL_SETUP from args if provided, else default to false

if [ "$FULL_SETUP" != "full" ]; then
    echo "Do you wish to continue and set up the DNS? [Y/n] "
    read yn
    case $yn in
        [Yy]* ) FULL_SETUP="full";;
        [Nn]* ) echo "DNS setup skipped. Exiting..."; exit;;
        * ) FULL_SETUP="full";;
    esac
fi

if [ "$FULL_SETUP" = "full" ]; then
    echo "--- Performing DNS setup ---"
    if [ ! -f "$SETUP_SCRIPTS_DIR/dns_setup.sh" ]; then
        error_exit "DNS setup script not found at $SETUP_SCRIPTS_DIR/dns_setup.sh. Please ensure it exists."
    fi
    source "$SETUP_SCRIPTS_DIR/dns_setup.sh" "$CONFIG_DIR" "$MAILDOMAIN" "$HOSTNAME" || error_exit "DNS setup failed."
    echo "DNS setup complete!"
fi


echo "Backend deployment complete!"
echo "Traefik dashboard (if enabled and configured) will be on port 80/443."

# --- Print generated credentials ---
echo ""
echo "--- Generated Credentials for Frontend Configuration ---"
GENERATED_API_URL="https://$HOSTNAME"

echo "WildDuck API URL: $GENERATED_API_URL"
echo "WildDuck API Token: $ACCESS_TOKEN"
echo "------------------------------------------------------"
