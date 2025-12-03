#!/bin/bash



args=("$@")

# install all dependencies
source "./setup-scripts/deps_setup.sh"
source "./setup-scripts/kill_ports.sh"

# config 

CONFIG_DIR="config-generated"


# clean files and folders

echo "cleaning files and folders removing config-gmerated and acme.json"
read -p "Are you sure you want to continue? [Y/n] " yn

case $yn in
    [Yy]* ) sudo rm -rf ./config-generated && sudo rm -rf ./acme.json && sudo rm -rf update_certs.sh;;
    [Nn]* ) echo "No files and folders removed. Exiting..."; exit;;
    * ) sudo rm -rf ./config-generated && sudo rm -rf ./acme.json && sudo rm -rf update_certs.sh;;
esac
SERVICES="Wildduck, Zone-MTA, Haraka, Mail Box Indexer"

echo "Setting up $SERVICES"

# Prompt for mail domain and hostnames
echo ""
echo "--- Domain Configuration ---"
read -p "Enter your mail domain (required): " MAILDOMAIN

if [ -z "$MAILDOMAIN" ]; then
    echo "Error: Mail domain cannot be empty"
    exit 1
fi

read -p "Enter your mail hostname for IMAP/SMTP (optional, press Enter to use 'mail.$MAILDOMAIN'): " HOSTNAME

if [ -z "$HOSTNAME" ]; then
    HOSTNAME="mail.$MAILDOMAIN"
    echo "Using mail hostname: $HOSTNAME"
fi

read -p "Enter your API hostname for REST APIs (optional, press Enter to use 'api.$MAILDOMAIN'): " API_HOSTNAME

if [ -z "$API_HOSTNAME" ]; then
    API_HOSTNAME="api.$MAILDOMAIN"
    echo "Using API hostname: $API_HOSTNAME"
fi

echo -e "MAIL DOMAIN: $MAILDOMAIN"
echo -e "MAIL HOSTNAME (IMAP/POP3/SMTP): $HOSTNAME"
echo -e "API HOSTNAME (REST APIs): $API_HOSTNAME"

# Indexer URL uses internal Docker service name
INDEXER_BASE_URL="http://mail_box_indexer:42069"

# Export the variable for current session
export INDEXER_BASE_URL="$INDEXER_BASE_URL"

# Copy default mail_box_indexer configuration as base
echo ""
echo "--- Mail Box Indexer Default Configuration ---"
if [ -f "default-config/mail_box_indexer/.env" ]; then
    echo "Copying default mail_box_indexer configuration..."
    cp default-config/mail_box_indexer/.env .env
    echo "✓ Default mail_box_indexer configuration copied to .env"
else
    echo "Warning: default-config/mail_box_indexer/.env not found, creating empty .env"
    touch .env
fi

# Update INDEXER_BASE_URL in the default config
if grep -q "^INDEXER_BASE_URL=" .env; then
    sed -i "s|^INDEXER_BASE_URL=.*|INDEXER_BASE_URL=$INDEXER_BASE_URL|" .env
else
    echo "INDEXER_BASE_URL=$INDEXER_BASE_URL" >> .env
fi

# Doppler Integration for WildDuck Secrets
echo ""
echo "--- WildDuck Secrets Configuration ---"

# Check for saved Doppler token
DOPPLER_TOKEN_FILE=".doppler-token"
DOPPLER_TOKEN=""

if [ -f "$DOPPLER_TOKEN_FILE" ]; then
    DOPPLER_TOKEN=$(cat "$DOPPLER_TOKEN_FILE")
    echo "Found saved Doppler token, validating..."
else
    echo "Enter your Doppler service token for WildDuck."
    echo "(This will download WILDDUCK_DBS_MONGO and other WildDuck secrets from Doppler)"
    echo ""
    read -p "Doppler service token: " DOPPLER_TOKEN

    if [ -z "$DOPPLER_TOKEN" ]; then
        echo "Error: Doppler token cannot be empty"
        exit 1
    fi
fi

echo "Downloading environment variables from Doppler..."

# Download from Doppler to a temporary file
DOPPLER_ENV_FILE=".env.doppler"
HTTP_CODE=$(curl -u "$DOPPLER_TOKEN:" \
    -w "%{http_code}" \
    -o "$DOPPLER_ENV_FILE" \
    -s \
    https://api.doppler.com/v3/configs/config/secrets/download?format=env)

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✓ Successfully downloaded secrets from Doppler"

    # Save the validated token for future use
    echo "$DOPPLER_TOKEN" > "$DOPPLER_TOKEN_FILE"
    chmod 600 "$DOPPLER_TOKEN_FILE"  # Secure the file
    echo "✓ Doppler token saved for future runs"

    # If .env exists, merge with Doppler taking precedence
    if [ -f .env ]; then
        echo "Merging Doppler secrets with existing .env file..."
        # Backup existing .env
        cp .env .env.backup

        # Merge: Keep existing .env, then overwrite with Doppler values
        cat .env.backup "$DOPPLER_ENV_FILE" | \
            awk -F= '!seen[$1]++ || /^[A-Z_]+=/' > .env.temp
        mv .env.temp .env

        echo "✓ Merged Doppler secrets (Doppler values take precedence)"
    else
        # No existing .env, just use Doppler file
        mv "$DOPPLER_ENV_FILE" .env
        echo "✓ Created .env from Doppler secrets"
    fi

    # Clean up
    rm -f "$DOPPLER_ENV_FILE" .env.backup

    echo "✓ WildDuck secrets configured from Doppler"
else
    echo "Error: Failed to download from Doppler (HTTP $HTTP_CODE)"

    # If we were using a saved token, remove it and ask for a new one
    if [ -f "$DOPPLER_TOKEN_FILE" ]; then
        echo "Saved token is invalid, removing it"
        rm -f "$DOPPLER_TOKEN_FILE"
        echo ""
        echo "Please enter your Doppler service token:"
        read -p "Doppler service token: " DOPPLER_TOKEN

        if [ -z "$DOPPLER_TOKEN" ]; then
            echo "Error: Doppler token cannot be empty"
            rm -f "$DOPPLER_ENV_FILE"
            exit 1
        fi

        # Retry with the new token
        echo "Retrying with new token..."
        HTTP_CODE=$(curl -u "$DOPPLER_TOKEN:" \
            -w "%{http_code}" \
            -o "$DOPPLER_ENV_FILE" \
            -s \
            https://api.doppler.com/v3/configs/config/secrets/download?format=env)

        if [ "$HTTP_CODE" -eq 200 ]; then
            echo "✓ Successfully downloaded secrets from Doppler"

            # Save the new validated token
            echo "$DOPPLER_TOKEN" > "$DOPPLER_TOKEN_FILE"
            chmod 600 "$DOPPLER_TOKEN_FILE"
            echo "✓ Doppler token saved for future runs"

            # Merge/create .env file
            if [ -f .env ]; then
                echo "Merging Doppler secrets with existing .env file..."
                cp .env .env.backup
                cat .env.backup "$DOPPLER_ENV_FILE" | \
                    awk -F= '!seen[$1]++ || /^[A-Z_]+=/' > .env.temp
                mv .env.temp .env
                echo "✓ Merged Doppler secrets (Doppler values take precedence)"
            else
                mv "$DOPPLER_ENV_FILE" .env
                echo "✓ Created .env from Doppler secrets"
            fi

            rm -f "$DOPPLER_ENV_FILE" .env.backup
            echo "✓ WildDuck secrets configured from Doppler"
        else
            echo "Error: Failed to download from Doppler with new token (HTTP $HTTP_CODE)"
            echo "Please check your service token and try again"
            rm -f "$DOPPLER_ENV_FILE"
            exit 1
        fi
    else
        echo "Please check your service token and try again"
        rm -f "$DOPPLER_ENV_FILE"
        exit 1
    fi
fi

# Update INDEXER_BASE_URL in .env
if grep -q "^INDEXER_BASE_URL=" .env; then
    sed -i "s|^INDEXER_BASE_URL=.*|INDEXER_BASE_URL=$INDEXER_BASE_URL|" .env
else
    echo "INDEXER_BASE_URL=$INDEXER_BASE_URL" >> .env
fi

# Source .env to check what we have
source .env

# Debug: Show what Doppler variables we loaded
echo ""
echo "--- Doppler Variables Loaded ---"
if [ -n "$WILDDUCK_DBS_MONGO" ]; then
    echo "✓ WILDDUCK_DBS_MONGO: $WILDDUCK_DBS_MONGO"
else
    echo "✗ WILDDUCK_DBS_MONGO: not set"
fi
if [ -n "$WILDDUCK_API_ROOTUSERNAME" ]; then
    echo "✓ WILDDUCK_API_ROOTUSERNAME: $WILDDUCK_API_ROOTUSERNAME"
else
    echo "✗ WILDDUCK_API_ROOTUSERNAME: not set"
fi
if [ -n "$WILDDUCK_EMAILDOMAIN" ]; then
    echo "✓ WILDDUCK_EMAILDOMAIN: $WILDDUCK_EMAILDOMAIN"
else
    echo "✗ WILDDUCK_EMAILDOMAIN: not set"
fi
if [ -n "$WILDDUCK_API_INDEXERBASEURL" ]; then
    echo "✓ WILDDUCK_API_INDEXERBASEURL: $WILDDUCK_API_INDEXERBASEURL"
else
    echo "✗ WILDDUCK_API_INDEXERBASEURL: not set"
fi
echo ""

# Prompt for Indexer Environment Variables only if not provided by Doppler
echo ""
echo "--- Mail Box Indexer Configuration ---"

if [ -n "$INDEXER_PRIVATE_KEY" ] && [ -n "$INDEXER_WALLET_ADDRESS" ]; then
    echo "✓ Using indexer credentials from Doppler"
else
    echo "The Mail Box Indexer requires blockchain wallet credentials."
    echo "These will be stored in the .env file."
    echo ""

    if [ -z "$INDEXER_PRIVATE_KEY" ]; then
        read -p "Enter Indexer Private Key: " INDEXER_PRIVATE_KEY
        if [ -z "$INDEXER_PRIVATE_KEY" ]; then
            echo "Error: Indexer private key cannot be empty"
            exit 1
        fi

        # Add/update indexer private key in .env
        if grep -q "^INDEXER_PRIVATE_KEY=" .env; then
            sed -i "s|^INDEXER_PRIVATE_KEY=.*|INDEXER_PRIVATE_KEY=$INDEXER_PRIVATE_KEY|" .env
        else
            echo "INDEXER_PRIVATE_KEY=$INDEXER_PRIVATE_KEY" >> .env
        fi
    else
        echo "✓ Using INDEXER_PRIVATE_KEY from Doppler"
    fi

    if [ -z "$INDEXER_WALLET_ADDRESS" ]; then
        read -p "Enter Indexer Wallet Address: " INDEXER_WALLET_ADDRESS
        if [ -z "$INDEXER_WALLET_ADDRESS" ]; then
            echo "Error: Indexer wallet address cannot be empty"
            exit 1
        fi

        # Add/update indexer wallet address in .env
        if grep -q "^INDEXER_WALLET_ADDRESS=" .env; then
            sed -i "s|^INDEXER_WALLET_ADDRESS=.*|INDEXER_WALLET_ADDRESS=$INDEXER_WALLET_ADDRESS|" .env
        else
            echo "INDEXER_WALLET_ADDRESS=$INDEXER_WALLET_ADDRESS" >> .env
        fi
    else
        echo "✓ Using INDEXER_WALLET_ADDRESS from Doppler"
    fi

    echo "✓ Indexer configuration saved"
fi

# CORS Configuration
echo ""
echo "--- CORS Configuration ---"

# Check if CORS origins are set in Doppler/environment
if [ -n "$WILDDUCK_CORS_ORIGINS" ]; then
    echo "Using CORS origins from environment: $WILDDUCK_CORS_ORIGINS"
    CORS_ORIGINS="$WILDDUCK_CORS_ORIGINS"
    CORS_ENABLED=true
else
    echo "CORS (Cross-Origin Resource Sharing) allows web browsers to access your WildDuck API from different domains."
    echo "This is typically needed if you have a web frontend that will access the API."
    echo ""
    read -p "Do you want to enable CORS for the WildDuck API? [Y/n] " ENABLE_CORS

    CORS_ORIGINS=""
    case $ENABLE_CORS in
        [Nn]* )
            echo "CORS will be disabled."
            CORS_ENABLED=false
            ;;
        * )
            echo "CORS will be enabled."
            CORS_ENABLED=true
            echo ""
            echo "You can specify which domains are allowed to access the API."
            echo "Examples:"
            echo "  - Use '*' to allow all domains (least secure, good for development)"
            echo "  - Use 'http://localhost:3000' for local development"
            echo "  - Use 'https://yourdomain.com' for production"
            echo ""
            read -p "Enter allowed origins (comma-separated, or '*' for all): " CORS_ORIGINS

            if [ -z "$CORS_ORIGINS" ]; then
                CORS_ORIGINS="*"
                echo "No origins specified, defaulting to '*' (all domains)"
            fi
            ;;
    esac
fi

# Ensure config-generated directory exists
mkdir -p config-generated

# Always copy fresh configuration files to avoid corrupted state
echo "Copying default configuration files..."
rm -rf ./config-generated/config
cp -r ./default-config ./config-generated/config
echo "✓ Configuration files copied successfully"

# SSL
# source "./setup-scripts/ssl_setup.sh"

# Docker compose
echo "Copying default docker-compose to ./config-generated"
cp ./docker-compose.yml ./config-generated/docker-compose.yml

# Copy .env file for mail_box_indexer configuration
if [ -f .env ]; then
    echo "Copying .env file to ./config-generated"
    cp .env ./config-generated/.env
else
    echo "Warning: No .env file found. Please copy .env.example to .env and configure it."
fi

# stop exisiting wildduck-dockerized container
sudo docker stop $(sudo docker ps -q --filter "name=^/config-generated")


# Traefik
echo "Copying Traefik config and replacing default configuration"
cp -r ./dynamic_conf ./config-generated
# Replace API_HOSTNAME first, then HOSTNAME (order matters to avoid partial replacement)
sed -i "s|API_HOSTNAME|$API_HOSTNAME|g" ./config-generated/docker-compose.yml
sed -i "s|HOSTNAME|$HOSTNAME|g" ./config-generated/docker-compose.yml

# Save hostnames to config file for upgrade.sh to use
echo "Saving deployment configuration..."
cat > ./config-generated/.deployment-config << EOF
# Deployment configuration (auto-generated by setup.sh)
MAIL_HOSTNAME=$HOSTNAME
API_HOSTNAME=$API_HOSTNAME
EOF
echo "✓ Deployment configuration saved"


# Mongo
# Only prompt for MongoDB configuration if not provided by Doppler
if [ -z "$WILDDUCK_DBS_MONGO" ]; then
    echo "WILDDUCK_DBS_MONGO not found in Doppler. Prompting for configuration..."
    source "./setup-scripts/mongo.sh"
else
    echo "Using MongoDB URL from Doppler: $WILDDUCK_DBS_MONGO"
    # Check if it's a local or remote MongoDB based on the URL
    if [[ "$WILDDUCK_DBS_MONGO" == *"mongo:27017"* ]] || [[ "$WILDDUCK_DBS_MONGO" == *"localhost"* ]] || [[ "$WILDDUCK_DBS_MONGO" == *"127.0.0.1"* ]]; then
        echo "Detected local MongoDB configuration"
    else
        echo "Detected remote MongoDB configuration"
        # Comment out local MongoDB service from docker-compose
        DOCKER_COMPOSE_FILE="./config-generated/docker-compose.yml"
        if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
            echo "Commenting out local MongoDB service from ${DOCKER_COMPOSE_FILE}..."
            sed -i -e '
            /^[[:space:]]\{2\}mongo:$/ {
                s/^/#/;
                :mongo_service_loop
                n;
                /^[[:space:]]\{4\}/ {
                    s/^/#/;
                    b mongo_service_loop;
                }
            }' "${DOCKER_COMPOSE_FILE}"

            echo "Commenting out local MongoDB volume from ${DOCKER_COMPOSE_FILE}..."
            sed -i -e '
            /^[[:space:]]*volumes:$/,/^[^[:space:]]/ {
                /^[[:space:]]\{2\}mongo:$/s/^/#/;
            }' "${DOCKER_COMPOSE_FILE}"

            echo "Removing mongo dependencies from services in ${DOCKER_COMPOSE_FILE}..."
            # Remove mongo: and its condition from depends_on blocks (new format with health checks)
            sed -i -e '
            /^[[:space:]]\{4\}depends_on:$/,/^[[:space:]]\{0,4\}[a-z]/ {
                /^[[:space:]]\{6\}mongo:$/,/^[[:space:]]\{8\}condition:/ {
                    /^[[:space:]]\{6\}mongo:$/d;
                    /^[[:space:]]\{8\}condition:/d;
                }
            }' "${DOCKER_COMPOSE_FILE}"

            # Also remove "- mongo" format (old format without health checks)
            sed -i -e '/^[[:space:]]*depends_on:/,/^[[:space:]]*[a-z_-]*:/ {
                /^[[:space:]]*-[[:space:]]*mongo$/d
            }' "${DOCKER_COMPOSE_FILE}"

            echo "✓ Configured docker-compose for remote MongoDB"
        fi
    fi
fi

# PostgreSQL
# Check if remote PostgreSQL is configured in Doppler
if [ -n "$DATABASE_URL" ]; then
    echo "Using PostgreSQL URL from Doppler: $DATABASE_URL"
    # Check if it's a local or remote PostgreSQL based on the URL
    if [[ "$DATABASE_URL" == *"postgres:5432"* ]] || [[ "$DATABASE_URL" == *"localhost"* ]] || [[ "$DATABASE_URL" == *"127.0.0.1"* ]]; then
        echo "Detected local PostgreSQL configuration"
    else
        echo "Detected remote PostgreSQL configuration"
        DOCKER_COMPOSE_FILE="./config-generated/docker-compose.yml"
        if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
            echo "Commenting out local PostgreSQL service from ${DOCKER_COMPOSE_FILE}..."
            sed -i -e '
            /^[[:space:]]\{2\}postgres:$/ {
                s/^/#/;
                :postgres_service_loop
                n;
                /^[[:space:]]\{4\}/ {
                    s/^/#/;
                    b postgres_service_loop;
                }
            }' "${DOCKER_COMPOSE_FILE}"

            echo "Commenting out local PostgreSQL volume from ${DOCKER_COMPOSE_FILE}..."
            sed -i -e '
            /^[[:space:]]*volumes:$/,/^[^[:space:]]/ {
                /^[[:space:]]\{2\}postgres:$/s/^/#/;
            }' "${DOCKER_COMPOSE_FILE}"

            echo "Removing postgres dependencies from services in ${DOCKER_COMPOSE_FILE}..."
            # Remove postgres: and its condition from depends_on blocks
            sed -i -e '
            /^[[:space:]]\{4\}depends_on:$/,/^[[:space:]]\{0,4\}[a-z]/ {
                /^[[:space:]]\{6\}postgres:$/,/^[[:space:]]\{8\}condition:/ {
                    /^[[:space:]]\{6\}postgres:$/d;
                    /^[[:space:]]\{8\}condition:/d;
                }
            }' "${DOCKER_COMPOSE_FILE}"

            echo "✓ Configured docker-compose for remote PostgreSQL"
        fi
    fi
else
    echo "No remote PostgreSQL URL found in Doppler. Using local PostgreSQL container."
fi

# Certs for traefik
USE_SELF_SIGNED_CERTS=false
read -p "Do you wish to set up self-signed certs for development? (y/N) " yn

    case $yn in
        [Yy]* ) USE_SELF_SIGNED_CERTS=true;;
        [Nn]* ) USE_SELF_SIGNED_CERTS=false;;
        * ) USE_SELF_SIGNED_CERTS=false;;
    esac

if $USE_SELF_SIGNED_CERTS; then
    echo "Generating self-signed TLS Certs"
    mkdir -p ./config-generated/certs

    openssl genrsa -out ./config-generated/certs/rootCA.key 4096
    openssl req -x509 -new -nodes -key ./config-generated/certs/rootCA.key -sha256 -days 3650 -out ./config-generated/certs/rootCA.pem -subj "/C=US/ST=State/L=City/O=Your Organization/CN=Your CA"
    openssl genrsa -out ./config-generated/certs/$HOSTNAME.key 2048
    openssl req -new -key ./config-generated/certs/$HOSTNAME.key -out ./config-generated/certs/$HOSTNAME.csr -subj "/C=US/ST=State/L=City/O=Your Organization/CN=$HOSTNAME"
    cat > ./config-generated/certs/$HOSTNAME.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $HOSTNAME
DNS.2 = *.$HOSTNAME
EOF
    openssl x509 -req -in ./config-generated/certs/$HOSTNAME.csr -CA ./config-generated/certs/rootCA.pem -CAkey ./config-generated/certs/rootCA.key -CAcreateserial -out ./config-generated/certs/$HOSTNAME.crt -days 825 -sha256 -extfile ./config-generated/certs/$HOSTNAME.ext
    mv ./config-generated/certs/$HOSTNAME.crt ./config-generated/certs/$HOSTNAME.pem
    mv ./config-generated/certs/$HOSTNAME.key ./config-generated/certs/$HOSTNAME-key.pem

    # Ensure Traefik's static config points at the generated certificate files
    sed -i "s/wildduck.dockerized.test/$HOSTNAME/g" ./config-generated/dynamic_conf/dynamic.yml
fi

# Haraka certs settings
# Replace the key line
sed -i "s|./certs/HOSTNAME-key.pem|./certs/$HOSTNAME-key.pem|g" ./config-generated/docker-compose.yml

# Replace the cert line
sed -i "s|./certs/HOSTNAME.pem|./certs/$HOSTNAME.pem|g" ./config-generated/docker-compose.yml

if ! $USE_SELF_SIGNED_CERTS; then
    # use let's encrypt
    sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.email=ACME_EMAIL\"|- \"--certificatesresolvers.letsencrypt.acme.email=domainadmin@$MAILDOMAIN\"|g" ./config-generated/docker-compose.yml
    sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|- \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|g" ./config-generated/docker-compose.yml
    sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|- \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|g" ./config-generated/docker-compose.yml

    # Uncomment the traefik.tcp.routers.zonemta.tls.certresolver line
    sed -i "s|# traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt|traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt|g" ./config-generated/docker-compose.yml

    # Uncomment the traefik.tcp.routers.wildduck-pop3s.tls.certresolver line
    sed -i "s|# traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt|traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt|g" ./config-generated/docker-compose.yml

    # Uncomment the traefik.tcp.routers.wildduck-imaps.tls.certresolver line
    sed -i "s|# traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt|traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt|g" ./config-generated/docker-compose.yml

    # Delete the traefik.tcp.routers.zonemta.tls: true line
    sed -i "/traefik.tcp.routers.zonemta.tls: true/d" ./config-generated/docker-compose.yml

    # Delete the traefik.tcp.routers.wildduck-pop3s.tls: true line
    sed -i "/traefik.tcp.routers.wildduck-pop3s.tls: true/d" ./config-generated/docker-compose.yml

    # Delete the traefik.tcp.routers.wildduck-imaps.tls: true line
    sed -i "/traefik.tcp.routers.wildduck-imaps.tls: true/d" ./config-generated/docker-compose.yml

    sed -i "/- \.\/dynamic_conf:\/etc\/traefik\/dynamic_conf:ro/d" ./config-generated/docker-compose.yml

    # Delete the providers.file=true line
    sed -i '/- "--providers.file=true"/d' ./config-generated/docker-compose.yml

    # Delete the providers.file.directory line
    sed -i '/- "--providers.file.directory=\/etc\/traefik\/dynamic_conf"/d' ./config-generated/docker-compose.yml

    # Delete the providers.file.watch line
    sed -i '/- "--providers.file.watch=true"/d' ./config-generated/docker-compose.yml

    # Delete the serversTransport.insecureSkipVerify line
    sed -i '/- "--serversTransport.insecureSkipVerify=true"/d' ./config-generated/docker-compose.yml

    # Delete the serversTransport.rootCAs line
    sed -i '/- "--serversTransport.rootCAs=\/etc\/traefik\/certs\/rootCA.pem"/d' ./config-generated/docker-compose.yml

    # Clear dynamic.yml since Let's Encrypt uses acme.json instead of static cert files
    # This prevents Traefik from trying to load non-existent certificate files
    echo "# Using Let's Encrypt - certificates managed via ACME" > ./config-generated/dynamic_conf/dynamic.yml
    echo "tls: {}" >> ./config-generated/dynamic_conf/dynamic.yml

    # # Delete the log.level=DEBUG line
    # sed -i '/- "--log.level=DEBUG"/d' ./config-generated/docker-compose.yml

    # Delete the certs line
    sed -i '/- \.\/certs:\/etc\/traefik\/certs.*# Mount your certs directory/d' ./config-generated/docker-compose.yml
fi

echo "Replacing domains in $SERVICES configuration"

# Zone-MTA
sed -i "s/name=\"example.com\"/name=\"$HOSTNAME\"/" ./config-generated/config/zone-mta/pools.toml
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config/zone-mta/plugins/wildduck.toml
sed -i "s/rewriteDomain=\"email.example.com\"/rewriteDomain=\"$MAILDOMAIN\"/" ./config-generated/config/zone-mta/plugins/wildduck.toml

# Wildduck
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config/wildduck/imap.toml
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config/wildduck/pop3.toml
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config/wildduck/default.toml
sed -i "s/rpId=\"email.example.com\"/rpId=\"$HOSTNAME\"/" ./config-generated/config/wildduck/default.toml

echo "Generating secrets and placing them in $SERVICES configuration"

# Source .env to get Doppler values
source .env

# Use WILDDUCK_EMAILDOMAIN from Doppler if available, otherwise use prompted MAILDOMAIN
EMAIL_DOMAIN_TO_USE=${WILDDUCK_EMAILDOMAIN:-$MAILDOMAIN}
sed -i "s/emailDomain=\"email.example.com\"/emailDomain=\"$EMAIL_DOMAIN_TO_USE\"/" ./config-generated/config/wildduck/default.toml
echo "✓ Set emailDomain to: $EMAIL_DOMAIN_TO_USE"

# Use Doppler values if available, otherwise generate randomly
# These secrets are needed for inter-service communication
SRS_SECRET=${WILDDUCK_SRS_SECRET:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)}
ZONEMTA_SECRET=${ZONEMTA_LOOP_SECRET:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)}
DKIM_SECRET=${WILDDUCK_DKIM_SECRET:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)}
HMAC_SECRET=${WILDDUCK_HMAC_SECRET:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)}

# MongoDB URL - use Doppler value or default to Docker service
MONGO_URL=${WILDDUCK_DBS_MONGO:-mongodb://mongo:27017/wildduck}

# Zone-MTA
sed -i "s/secret=\"super secret value\"/secret=\"$ZONEMTA_SECRET\"/" ./config-generated/config/zone-mta/plugins/loop-breaker.toml
sed -i "s/secret=\"secret value\"/secret=\"$SRS_SECRET\"/" ./config-generated/config/zone-mta/plugins/wildduck.toml
# IMPORTANT: DKIM secret must be the same in ZoneMTA and WildDuck for DKIM signing to work
# ZoneMTA uses this secret to decrypt DKIM private keys that WildDuck encrypted
sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" ./config-generated/config/zone-mta/plugins/wildduck.toml

# ZoneMTA and WildDuck Database Configuration
# =============================================
# Both ZoneMTA and WildDuck must use the same database name. ZoneMTA writes to
# the 'sender' database collection, and WildDuck reads from it for outbound mail.
# Extract database name from MONGO_URL (get the part after the last /, strip query parameters and trailing slashes)
DB_NAME=$(echo "$MONGO_URL" | sed 's/.*\///' | sed 's/?.*//' | sed 's/\/$//')

# Validate that we successfully extracted a database name
if [ -z "$DB_NAME" ]; then
    echo "Error: Could not extract database name from MongoDB URL: $MONGO_URL"
    echo "Please ensure your MongoDB URL is in the correct format (e.g., mongodb://host:port/database)"
    exit 1
fi

echo ""
echo "=== Database Configuration ==="
echo "MongoDB URL: $MONGO_URL"
echo "Database Name: $DB_NAME"
echo ""
echo "Configuring ZoneMTA and WildDuck to use database: $DB_NAME"

# Update both development and production ZoneMTA config files to use the correct database
echo "Updating ZoneMTA database configuration files..."
ZONEMTA_FILES_UPDATED=0
for DBS_FILE in ./config-generated/config/zone-mta/dbs-*.toml; do
    if [ -f "$DBS_FILE" ]; then
        echo "  → $(basename "$DBS_FILE"): mongo=$MONGO_URL, sender=$DB_NAME"
        sed -i "s|mongo = \".*\"|mongo = \"$MONGO_URL\"|" "$DBS_FILE"
        sed -i "s|sender = \".*\"|sender = \"$DB_NAME\"|" "$DBS_FILE"
        ZONEMTA_FILES_UPDATED=$((ZONEMTA_FILES_UPDATED + 1))
    fi
done

if [ $ZONEMTA_FILES_UPDATED -eq 0 ]; then
    echo "  Warning: No ZoneMTA database config files found to update"
else
    echo "  ✓ Updated $ZONEMTA_FILES_UPDATED ZoneMTA database configuration file(s)"
fi

# Wildduck - sender and dkim
sed -i "s/#loopSecret=\"secret value\"/loopSecret=\"$SRS_SECRET\"/" ./config-generated/config/wildduck/sender.toml
# IMPORTANT: This DKIM secret must match ZoneMTA's DKIM secret (see above)
# WildDuck encrypts DKIM private keys with this secret, ZoneMTA decrypts them for signing
sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" ./config-generated/config/wildduck/dkim.toml

# Wildduck - api.toml: Copy from wildduck repo or use default config
echo "Configuring WildDuck API..."
if [ -f "../wildduck/config/api.toml" ]; then
    cp "../wildduck/config/api.toml" ./config-generated/config/wildduck/api.toml
    echo "✓ Copied api.toml from wildduck repo"
else
    echo "✓ Using default api.toml from default-config"
fi

# Always apply these configurations regardless of source
echo "✓ Applying HMAC secret for accessControl"
sed -i "s|secret = \"a secret cat\"|secret = \"$HMAC_SECRET\"|" ./config-generated/config/wildduck/api.toml

# Use WILDDUCK_API_INDEXERBASEURL from Doppler if available, otherwise use INDEXER_BASE_URL
INDEXER_URL_TO_USE=${WILDDUCK_API_INDEXERBASEURL:-$INDEXER_BASE_URL}
echo "✓ Setting indexerBaseUrl to: $INDEXER_URL_TO_USE"
sed -i "s|indexerBaseUrl = \".*\"|indexerBaseUrl = \"$INDEXER_URL_TO_USE\"|" ./config-generated/config/wildduck/api.toml

# Apply optional Doppler overrides if they exist
if [ -n "$WILDDUCK_API_ROOTUSERNAME" ]; then
    echo "✓ Applying WILDDUCK_API_ROOTUSERNAME from Doppler: $WILDDUCK_API_ROOTUSERNAME"
    sed -i "s|rootUsername = \"admin\"|rootUsername = \"$WILDDUCK_API_ROOTUSERNAME\"|" ./config-generated/config/wildduck/api.toml
    sed -i "s|rootUsername = \"0x[a-fA-F0-9]*\"|rootUsername = \"$WILDDUCK_API_ROOTUSERNAME\"|" ./config-generated/config/wildduck/api.toml
fi

# Apply optional Doppler overrides (commented out by default)
# Note: WILDDUCK_ACCESS_TOKEN and WILDDUCK_ACCESSCONTROL_ENABLED are NOT applied by default
# to keep the API accessible without authentication (both source configs have auth disabled)
# If you need authentication, manually edit config-generated/config/wildduck/api.toml

# if [ -n "$WILDDUCK_ACCESS_TOKEN" ]; then
#     echo "✓ Applying WILDDUCK_ACCESS_TOKEN from Doppler"
#     sed -i "s|# accessToken=\"somesecretvalue\"|accessToken=\"$WILDDUCK_ACCESS_TOKEN\"|" ./config-generated/config/wildduck/api.toml
#     sed -i "s|accessToken=\"somesecretvalue\"|accessToken=\"$WILDDUCK_ACCESS_TOKEN\"|" ./config-generated/config/wildduck/api.toml
# fi

# if [ -n "$WILDDUCK_ACCESSCONTROL_ENABLED" ]; then
#     echo "✓ Applying WILDDUCK_ACCESSCONTROL_ENABLED from Doppler"
#     sed -i "s|enabled = false|enabled = $WILDDUCK_ACCESSCONTROL_ENABLED|" ./config-generated/config/wildduck/api.toml
# fi

# Update WildDuck database configuration
echo ""
echo "Updating WildDuck database configuration..."
echo "  → dbs.toml: mongo=$MONGO_URL, sender=$DB_NAME"
sed -i "s|mongo = \".*\"|mongo = \"$MONGO_URL\"|" ./config-generated/config/wildduck/dbs.toml
sed -i "s|sender = \".*\"|sender = \"$DB_NAME\"|" ./config-generated/config/wildduck/dbs.toml
echo "  ✓ Updated WildDuck database configuration"

echo ""
echo "✓ Database configuration complete"
echo ""

# Apply CORS configuration
echo "Applying CORS configuration to WildDuck API..."

# Remove any existing CORS section
sed -i '/^\[cors\]/,/^$/d' ./config-generated/config/wildduck/api.toml
sed -i '/^# \[cors\]/,/^$/d' ./config-generated/config/wildduck/api.toml

# Add CORS section (always required by WildDuck)
echo "" >> ./config-generated/config/wildduck/api.toml
echo "[cors]" >> ./config-generated/config/wildduck/api.toml

if [ "$CORS_ENABLED" = true ]; then
    # Enable CORS with specified origins
    # Convert comma-separated origins to TOML array format
    TOML_ORIGINS=$(echo "$CORS_ORIGINS" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    echo "origins = $TOML_ORIGINS" >> ./config-generated/config/wildduck/api.toml
    echo "CORS enabled with origins: $CORS_ORIGINS"
else
    # Disable CORS with empty array
    echo "origins = []" >> ./config-generated/config/wildduck/api.toml
    echo "CORS disabled"
fi
sed -i "s/\"domainadmin@example.com\"/\"domainadmin@$MAILDOMAIN\"/" ./config-generated/config/wildduck/acme.toml
sed -i "s/\"https:\/\/wildduck.email\"/\"https:\/\/$MAILDOMAIN\"/" ./config-generated/config/wildduck/acme.toml

# Haraka
echo "Configuring Haraka..."
sed -i "s/#loopSecret: \"secret value\"/loopSecret: \"$SRS_SECRET\"/" ./config-generated/config/haraka/wildduck.yaml
sed -i "s/secret: \"secret value\"/secret: \"$SRS_SECRET\"/" ./config-generated/config/haraka/wildduck.yaml
sed -i "s|url: \".*\"|url: \"$MONGO_URL\"|" ./config-generated/config/haraka/wildduck.yaml

# Configure Haraka SMTP greeting banner
echo "  → Setting Haraka SMTP greeting to: $HOSTNAME"
# Update connection.ini [message] section greeting
sed -i "s/greeting=HOSTNAME ESMTP Haraka/greeting=$HOSTNAME ESMTP Haraka/" ./config-generated/config/haraka/connection.ini
# Update smtpgreeting file
echo "$HOSTNAME ESMTP Haraka" > ./config-generated/config/haraka/smtpgreeting
echo "  ✓ Haraka configuration complete"

# Mail Box Indexer - Set EMAIL_DOMAIN in docker-compose
echo "Configuring Mail Box Indexer..."
sed -i "s/EMAIL_DOMAIN:-0xmail.box/EMAIL_DOMAIN:-$MAILDOMAIN/g" ./config-generated/docker-compose.yml

# Haraka certs from Traefik
if ! $USE_SELF_SIGNED_CERTS; then
    echo "Getting certs for Haraka from Traefik"

    CERT_READY=false

    # Check if acme.json already exists with valid certificates
    if [ -f "./acme.json" ]; then
        echo "Found existing acme.json, checking for certificate..."
        if jq -e --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain)' ./acme.json >/dev/null 2>&1; then
            CERT_READY=true
            echo "✓ Certificate for $HOSTNAME already exists in acme.json"
        else
            echo "No certificate found in existing acme.json, will try to obtain new one"
        fi
    fi

    # Only start Traefik and wait if we don't have a certificate yet
    if [ "$CERT_READY" = false ]; then
        CURRENT_DIR=$(basename "$(pwd)")
        if [ -f "docker-compose.yml" ] && [ "$CURRENT_DIR" = "config-generated" ]; then
            sudo docker compose up traefik wildduck -d
            cd ../
        else
            cd ./config-generated/
            sudo docker compose up traefik wildduck -d
            cd ../
        fi

        echo "Waiting for Traefik to obtain certificate for $HOSTNAME..."
        # Poll the acme.json until the cert appears or timeout
        echo "Waiting for container to start..."
        sleep 2 # Just in case

        TIMEOUT=120 #increased timeout for cert acquisition
        INTERVAL=5
        ELAPSED=0

        while [ $ELAPSED -lt $TIMEOUT ]; do
          CONTAINER_ID=$(sudo docker ps --filter "name=traefik" --format "{{.ID}}")

          # Copy acme.json from inside the container
          sudo docker cp $CONTAINER_ID:/data/acme.json ./acme.json 2>/dev/null
          sudo chmod a+r ./acme.json

          # Check if the cert exists in acme.json
          if jq -e --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain)' ./acme.json >/dev/null 2>&1; then
              CERT_READY=true
              echo "Certificate found for $HOSTNAME."
              break
          fi

          echo "Waiting... ($ELAPSED/${TIMEOUT}s)"
          sleep $INTERVAL
          ELAPSED=$((ELAPSED + INTERVAL))
        done

        if [ "$CERT_READY" = false ]; then
            echo "⚠ Warning: Certificate for $HOSTNAME not found in acme.json after $TIMEOUT seconds."
            echo "This may be due to Let's Encrypt rate limiting or connectivity issues."
            echo "Setup will continue, but Haraka may fail to start without certificates."
            echo ""
            echo "You can:"
            echo "  1. Wait for rate limit to expire and re-run setup.sh"
            echo "  2. Manually extract certificates later when available"
            echo "  3. Continue with setup for now and fix certificates later"
            echo ""
            read -p "Continue anyway? [Y/n] " CONTINUE_ANYWAY
            case $CONTINUE_ANYWAY in
                [Nn]* )
                    echo "Setup aborted. Please resolve certificate issues and try again."
                    exit 1
                    ;;
                * )
                    echo "Continuing setup without certificates..."
                    ;;
            esac
        fi
    fi
    
    mkdir -p ./config-generated/certs/
    CERT_FILE="./config-generated/certs/$HOSTNAME.pem"
    KEY_FILE="./config-generated/certs/$HOSTNAME-key.pem"

    # Only extract certificates if they're available
    if [ "$CERT_READY" = true ]; then
        echo "Extracting certificates from acme.json..."

        # Extract the certificate
        CERT=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .certificate' acme.json)

        # Extract the private key
        KEY=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .key' acme.json)

        # Validate certificate and key were extracted
        if [ -z "$CERT" ] || [ "$CERT" = "null" ]; then
            echo "⚠ Warning: Could not extract certificate for $HOSTNAME from acme.json"
            CERT_READY=false
        elif [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
            echo "⚠ Warning: Could not extract private key for $HOSTNAME from acme.json"
            CERT_READY=false
        else
            # Remove any existing certificate directories (cleanup from failed runs)
            if [ -d "$CERT_FILE" ]; then
                echo "Removing certificate directory (from failed previous run)"
                sudo rm -rf "$CERT_FILE"
            fi
            if [ -d "$KEY_FILE" ]; then
                echo "Removing key directory (from failed previous run)"
                sudo rm -rf "$KEY_FILE"
            fi

            # Decode and save certificate
            echo "$CERT" | base64 -d > "$CERT_FILE"

            # Decode and save private key
            echo "$KEY" | base64 -d > "$KEY_FILE"

            # Verify files were created successfully
            if [ ! -f "$CERT_FILE" ] || [ ! -s "$CERT_FILE" ]; then
                echo "⚠ Warning: Certificate file was not created properly"
                CERT_READY=false
            elif [ ! -f "$KEY_FILE" ] || [ ! -s "$KEY_FILE" ]; then
                echo "⚠ Warning: Key file was not created properly"
                CERT_READY=false
            else
                echo "✓ Successfully created certificate files"

                # Copy certificates to Haraka config directory
                # (Haraka mounts the entire config directory, so certificates need to be inside it)
                echo "Copying certificates to Haraka config directory..."
                sudo cp "$CERT_FILE" "./config-generated/config/haraka/tls_cert.pem"
                sudo cp "$KEY_FILE" "./config-generated/config/haraka/tls_key.pem"
                echo "✓ Certificates copied to Haraka config"
            fi
        fi
    fi

    if [ "$CERT_READY" = false ]; then
        echo ""
        echo "⚠ Certificate files not available. Haraka will not start until certificates are present."
        echo "After certificates are obtained, extract them with:"
        echo "  cd /root/wildduck-dockerized && ./update_certs.sh"
        echo ""
    fi

    # Update Traefik dynamic configuration to point at the generated certs
    sed -i "s/wildduck.dockerized.test/$HOSTNAME/g" ./config-generated/dynamic_conf/dynamic.yml

    cd ./config-generated/ 
    sudo docker compose down
    cd ../

    # Create script to update certificates
    cat > update_certs.sh << 'EOF'
#!/bin/bash

# Import the HOSTNAME variable from the original script environment
HOSTNAME="$HOSTNAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACME_PATH="$SCRIPT_DIR/acme.json"
NEW_ACME_PATH="$SCRIPT_DIR/acme.json.new"
CERT_FILE="$SCRIPT_DIR/config-generated/certs/$HOSTNAME.pem"
KEY_FILE="$SCRIPT_DIR/config-generated/certs/$HOSTNAME-key.pem"

# Get container ID for Traefik
CONTAINER_ID=$(sudo docker ps --filter "name=traefik" --format "{{.ID}}")

if [ -z "$CONTAINER_ID" ]; then
    echo "Traefik container not running. Starting it..."
    
    CURRENT_DIR=$(basename "$(pwd)")
    if [ -f "docker-compose.yml" ] && [ "$CURRENT_DIR" = "config-generated" ]; then
        sudo docker compose up traefik -d 
    else
        cd ./config-generated/ 
        sudo docker compose up traefik -d
        cd "$SCRIPT_DIR"
    fi
    
    echo "Waiting for container to start..."
    sleep 2
    CONTAINER_ID=$(sudo docker ps --filter "name=traefik" --format "{{.ID}}")
    
    if [ -z "$CONTAINER_ID" ]; then
        echo "Failed to start Traefik container. Exiting."
        exit 1
    fi
fi

# Copy the acme.json file from Traefik container
sudo docker cp $CONTAINER_ID:/data/acme.json $NEW_ACME_PATH

# Check if acme.json has changed
if [ -f "$ACME_PATH" ] && diff -q "$ACME_PATH" "$NEW_ACME_PATH" >/dev/null; then
    echo "No changes in certificates detected."
    rm "$NEW_ACME_PATH"
    exit 0
fi

# Replace the old acme.json with the new one
mv "$NEW_ACME_PATH" "$ACME_PATH"

echo "Certificate changes detected. Updating certificate files..."

# Extract the certificate
CERT=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .certificate' $ACME_PATH)

# Extract the private key
KEY=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .key' $ACME_PATH)

# Check if we actually got the certificate and key
if [ -z "$CERT" ] || [ "$CERT" == "null" ]; then
    echo "Error: Certificate for $HOSTNAME not found!"
    exit 1
fi

if [ -z "$KEY" ] || [ "$KEY" == "null" ]; then
    echo "Error: Key for $HOSTNAME not found!"
    exit 1
fi

# Create directory if it doesn't exist
mkdir -p "$(dirname "$CERT_FILE")"

# Remove any existing certificate directories (cleanup from failed runs)
if [ -d "$CERT_FILE" ]; then
    echo "Removing certificate directory (from failed previous run)"
    sudo rm -rf "$CERT_FILE"
fi
if [ -d "$KEY_FILE" ]; then
    echo "Removing key directory (from failed previous run)"
    sudo rm -rf "$KEY_FILE"
fi

# Decode and save certificate
echo "$CERT" | base64 -d > "$CERT_FILE"

# Decode and save private key
echo "$KEY" | base64 -d > "$KEY_FILE"

# Verify files were created successfully
if [ ! -f "$CERT_FILE" ] || [ ! -s "$CERT_FILE" ]; then
    echo "Error: Certificate file was not created properly"
    exit 1
fi

if [ ! -f "$KEY_FILE" ] || [ ! -s "$KEY_FILE" ]; then
    echo "Error: Key file was not created properly"
    exit 1
fi

# Copy certificates to Haraka config directory
echo "Copying certificates to Haraka config directory..."
sudo cp "$CERT_FILE" "$SCRIPT_DIR/config-generated/config/haraka/tls_cert.pem"
sudo cp "$KEY_FILE" "$SCRIPT_DIR/config-generated/config/haraka/tls_key.pem"

echo "Certificate and key updated successfully at $(date)"

# Don't stop the container if it was already running
EOF
    # Pass the HOSTNAME variable to the script during creation
    sed -i "s/HOSTNAME=\"\$HOSTNAME\"/HOSTNAME=\"$HOSTNAME\"/" update_certs.sh

    # Make the script executable
    chmod +x update_certs.sh

    # Add weekly cron job to check for certificate updates
    CRON_JOB="0 0 * * 0 $(pwd)/update_certs.sh >> $(pwd)/cert_update.log 2>&1"
    (crontab -l 2>/dev/null || echo "") | grep -v "update_certs.sh" | { cat; echo "$CRON_JOB"; } | crontab -

    echo "Weekly certificate update check scheduled for every Sunday at midnight"
    echo "The script will check if Traefik has renewed the certificate and update the files accordingly"
fi

# Start all services
echo ""
echo "Starting all services..."
cd ./config-generated/
sudo docker compose up -d
cd ../

echo ""
echo "✓ Setup completed successfully!"
echo ""
echo "Service status:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "wildduck|zonemta|haraka|mail_box_indexer|traefik"

# Always run DNS setup
source "./setup-scripts/dns_setup.sh"
