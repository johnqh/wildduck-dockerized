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

# Mail domain and hostname are hardcoded
MAILDOMAIN="0xmail.box"
HOSTNAME="mail.0xmail.box"

echo -e "MAIL DOMAIN: $MAILDOMAIN, HOSTNAME: $HOSTNAME"

# Indexer URL uses internal Docker service name
INDEXER_BASE_URL="http://mail_box_indexer:42069"

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

# Doppler Integration for WildDuck Secrets
echo ""
echo "--- WildDuck Secrets Configuration ---"
echo "Do you want to use Doppler for WildDuck secrets (MongoDB URL, API tokens, etc.)?"
echo ""
read -p "Use Doppler for WildDuck secrets? [Y/n] " USE_DOPPLER

case $USE_DOPPLER in
    [Nn]* )
        echo "Skipping Doppler integration for WildDuck secrets."
        ;;
    * )
        echo "Enter your Doppler service token for WildDuck."
        echo "(This will download MongoDB URL and other WildDuck secrets from Doppler)"
        echo ""
        read -p "Doppler service token: " DOPPLER_TOKEN

        if [ -z "$DOPPLER_TOKEN" ]; then
            echo "Error: Doppler token cannot be empty"
            exit 1
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
            echo "Please check your service token and try again"
            rm -f "$DOPPLER_ENV_FILE"
            exit 1
        fi
        ;;
esac

# Update INDEXER_BASE_URL in .env
if grep -q "^INDEXER_BASE_URL=" .env; then
    sed -i "s|^INDEXER_BASE_URL=.*|INDEXER_BASE_URL=$INDEXER_BASE_URL|" .env
else
    echo "INDEXER_BASE_URL=$INDEXER_BASE_URL" >> .env
fi

# Source .env to check what we have
source .env

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

# Copy default configuration files if they don't exist
if [ ! -e ./config-generated/config-generated ]; then
    echo "Copying default configuration into ./config-generated/config-generated"
    cp -r ./default-config ./config-generated/config-generated
else
    echo "Configuration files already exist in ./config-generated/config-generated"
fi

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
sed -i "s|\./config/|./config-generated/|g" ./config-generated/docker-compose.yml
sed -i "s|HOSTNAME|$HOSTNAME|g" ./config-generated/docker-compose.yml


# Mongo
# Only prompt for MongoDB configuration if not provided by Doppler
if [ -z "$WILDDUCK_MONGO_URL" ]; then
    echo "MongoDB URL not found in Doppler. Prompting for configuration..."
    source "./setup-scripts/mongo.sh"
else
    echo "Using MongoDB URL from Doppler: $WILDDUCK_MONGO_URL"
    # Check if it's a local or remote MongoDB based on the URL
    if [[ "$WILDDUCK_MONGO_URL" == *"mongo:27017"* ]] || [[ "$WILDDUCK_MONGO_URL" == *"localhost"* ]] || [[ "$WILDDUCK_MONGO_URL" == *"127.0.0.1"* ]]; then
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
if [ -n "$POSTGRES_URL" ]; then
    echo "Using PostgreSQL URL from Doppler: $POSTGRES_URL"
    # Check if it's a local or remote PostgreSQL based on the URL
    if [[ "$POSTGRES_URL" == *"postgres:5432"* ]] || [[ "$POSTGRES_URL" == *"localhost"* ]] || [[ "$POSTGRES_URL" == *"127.0.0.1"* ]]; then
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

            # Update DATABASE_URL environment variable in mail_box_indexer
            echo "Updating DATABASE_URL in mail_box_indexer service..."
            sed -i "s|DATABASE_URL=postgresql://ponder:password@postgres:5432/mail_box_indexer|DATABASE_URL=${POSTGRES_URL}|g" "${DOCKER_COMPOSE_FILE}"

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
fi

# Haraka certs settings
# Replace the key line
sed -i 's|./certs/HOSTNAME-key.pem|./certs/$HOSTNAME-key.pem|g' ./config-generated/docker-compose.yml

# Replace the cert line
sed -i 's|./certs/HOSTNAME.pem|./certs/$HOSTNAME.pem|g' ./config-generated/docker-compose.yml

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

    # # Delete the log.level=DEBUG line
    # sed -i '/- "--log.level=DEBUG"/d' ./config-generated/docker-compose.yml

    # Delete the certs line
    sed -i '/- \.\/certs:\/etc\/traefik\/certs.*# Mount your certs directory/d' ./config-generated/docker-compose.yml
fi

echo "Replacing domains in $SERVICES configuration"

# Zone-MTA
sed -i "s/name=\"example.com\"/name=\"$HOSTNAME\"/" ./config-generated/config-generated/zone-mta/pools.toml
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config-generated/zone-mta/plugins/wildduck.toml
sed -i "s/rewriteDomain=\"email.example.com\"/rewriteDomain=\"$MAILDOMAIN\"/" ./config-generated/config-generated/zone-mta/plugins/wildduck.toml

# Wildduck
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config-generated/wildduck/imap.toml
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config-generated/wildduck/pop3.toml
sed -i "s/hostname=\"email.example.com\"/hostname=\"$HOSTNAME\"/" ./config-generated/config-generated/wildduck/default.toml
sed -i "s/rpId=\"email.example.com\"/rpId=\"$HOSTNAME\"/" ./config-generated/config-generated/wildduck/default.toml
sed -i "s/emailDomain=\"email.example.com\"/emailDomain=\"$MAILDOMAIN\"/" ./config-generated/config-generated/wildduck/default.toml

echo "Generating secrets and placing them in $SERVICES configuration"

# Source .env to get Doppler values
source .env

# Use Doppler values if available, otherwise generate randomly for Zone-MTA secrets
SRS_SECRET=${WILDDUCK_SRS_SECRET:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)}
ZONEMTA_SECRET=${ZONEMTA_LOOP_SECRET:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)}
DKIM_SECRET=${WILDDUCK_DKIM_SECRET:-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c30)}

# MongoDB URL - use Doppler value or default to Docker service
MONGO_URL=${WILDDUCK_MONGO_URL:-mongodb://mongo:27017/wildduck}

# Zone-MTA
sed -i "s/secret=\"super secret value\"/secret=\"$ZONEMTA_SECRET\"/" ./config-generated/config-generated/zone-mta/plugins/loop-breaker.toml
sed -i "s/secret=\"secret value\"/secret=\"$SRS_SECRET\"/" ./config-generated/config-generated/zone-mta/plugins/wildduck.toml
sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" ./config-generated/config-generated/zone-mta/plugins/wildduck.toml
sed -i "s|mongo = \".*\"|mongo = \"$MONGO_URL\"|" ./config-generated/config-generated/zone-mta/dbs-production.toml

# Wildduck - sender and dkim
sed -i "s/#loopSecret=\"secret value\"/loopSecret=\"$SRS_SECRET\"/" ./config-generated/config-generated/wildduck/sender.toml
sed -i "s/secret=\"super secret key\"/secret=\"$DKIM_SECRET\"/" ./config-generated/config-generated/wildduck/dkim.toml

# Wildduck - api.toml: Copy from wildduck repo, then overwrite with Doppler values only if they exist
echo "Configuring WildDuck API from source repo..."
if [ -f "../wildduck/config/api.toml" ]; then
    cp "../wildduck/config/api.toml" ./config-generated/config-generated/wildduck/api.toml
    echo "✓ Copied api.toml from wildduck repo"

    # Only apply Doppler values if they exist (don't generate random values)
    if [ -n "$WILDDUCK_ACCESS_TOKEN" ]; then
        echo "✓ Applying WILDDUCK_ACCESS_TOKEN from Doppler"
        sed -i "s|# accessToken=\"somesecretvalue\"|accessToken=\"$WILDDUCK_ACCESS_TOKEN\"|" ./config-generated/config-generated/wildduck/api.toml
        sed -i "s|accessToken=\"somesecretvalue\"|accessToken=\"$WILDDUCK_ACCESS_TOKEN\"|" ./config-generated/config-generated/wildduck/api.toml
    fi

    if [ -n "$WILDDUCK_HMAC_SECRET" ]; then
        echo "✓ Applying WILDDUCK_HMAC_SECRET from Doppler"
        sed -i "s|secret = \"a secret cat\"|secret = \"$WILDDUCK_HMAC_SECRET\"|" ./config-generated/config-generated/wildduck/api.toml
    fi

    if [ -n "$WILDDUCK_ROOT_USERNAME" ]; then
        echo "✓ Applying WILDDUCK_ROOT_USERNAME from Doppler"
        sed -i "s|rootUsername = \"admin\"|rootUsername = \"$WILDDUCK_ROOT_USERNAME\"|" ./config-generated/config-generated/wildduck/api.toml
    fi

    if [ -n "$WILDDUCK_ACCESSCONTROL_ENABLED" ]; then
        echo "✓ Applying WILDDUCK_ACCESSCONTROL_ENABLED from Doppler"
        sed -i "s|enabled = false|enabled = $WILDDUCK_ACCESSCONTROL_ENABLED|" ./config-generated/config-generated/wildduck/api.toml
    fi

    # Always set indexerBaseUrl to internal Docker service
    sed -i "s|indexerBaseUrl = \".*\"|indexerBaseUrl = \"$INDEXER_BASE_URL\"|" ./config-generated/config-generated/wildduck/api.toml
else
    echo "Warning: ../wildduck/config/api.toml not found. Using default config."
fi

sed -i "s|mongo = \".*\"|mongo = \"$MONGO_URL\"|" ./config-generated/config-generated/wildduck/dbs.toml

# Apply CORS configuration
echo "Applying CORS configuration to WildDuck API..."

# Remove any existing CORS section
sed -i '/^\[cors\]/,/^$/d' ./config-generated/config-generated/wildduck/api.toml
sed -i '/^# \[cors\]/,/^$/d' ./config-generated/config-generated/wildduck/api.toml

# Add CORS section (always required by WildDuck)
echo "" >> ./config-generated/config-generated/wildduck/api.toml
echo "[cors]" >> ./config-generated/config-generated/wildduck/api.toml

if [ "$CORS_ENABLED" = true ]; then
    # Enable CORS with specified origins
    # Convert comma-separated origins to TOML array format
    TOML_ORIGINS=$(echo "$CORS_ORIGINS" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    echo "origins = $TOML_ORIGINS" >> ./config-generated/config-generated/wildduck/api.toml
    echo "CORS enabled with origins: $CORS_ORIGINS"
else
    # Disable CORS with empty array
    echo "origins = []" >> ./config-generated/config-generated/wildduck/api.toml
    echo "CORS disabled"
fi
sed -i "s/\"domainadmin@example.com\"/\"domainadmin@$MAILDOMAIN\"/" ./config-generated/config-generated/wildduck/acme.toml
sed -i "s/\"https:\/\/wildduck.email\"/\"https:\/\/$MAILDOMAIN\"/" ./config-generated/config-generated/wildduck/acme.toml

# Haraka
sed -i "s/#loopSecret: \"secret value\"/loopSecret: \"$SRS_SECRET\"/" ./config-generated/config-generated/haraka/wildduck.yaml
sed -i "s/secret: \"secret value\"/secret: \"$SRS_SECRET\"/" ./config-generated/config-generated/haraka/wildduck.yaml
sed -i "s|url: \".*\"|url: \"$MONGO_URL\"|" ./config-generated/config-generated/haraka/wildduck.yaml

# Mail Box Indexer - Set EMAIL_DOMAIN in docker-compose
echo "Configuring Mail Box Indexer..."
sed -i "s/EMAIL_DOMAIN:-0xmail.box/EMAIL_DOMAIN:-$MAILDOMAIN/g" ./config-generated/docker-compose.yml

# Haraka certs from Traefik
if ! $USE_SELF_SIGNED_CERTS; then
    echo "Getting certs for Haraka from Traefik"

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
    CERT_READY=false
    

    while [ $ELAPSED -lt $TIMEOUT ]; do
      CONTAINER_ID=$(sudo docker ps --filter "name=traefik" --format "{{.ID}}")

      # Copy acme.json from inside the container
      sudo docker cp $CONTAINER_ID:/data/acme.json ./acme.json 2>/dev/null
      sudo chmod a+r ./acme.json

      # Check if the cert exists in acme.json
      if jq -e --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain)' ./acme.json >/dev/null; then
          CERT_READY=true
          echo "Certificate found for $HOSTNAME."
          break
      fi

      echo "Waiting... ($ELAPSED/${TIMEOUT}s)"
      sleep $INTERVAL
      ELAPSED=$((ELAPSED + INTERVAL))
    done

    if [ "$CERT_READY" = false ]; then
        echo "Error: Certificate for $HOSTNAME not found in acme.json after $TIMEOUT seconds."
        exit 1
    fi
    
    mkdir ./config-generated/certs/
    CERT_FILE="./config-generated/certs/$HOSTNAME.pem"
    KEY_FILE="./config-generated/certs/$HOSTNAME-key.pem"


    # Extract the certificate
    CERT=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .certificate' acme.json)
    
    # Extract the private key
    KEY=$(sudo jq -r --arg domain "$HOSTNAME" '.letsencrypt.Certificates[] | select(.domain.main == $domain) | .key' acme.json)

    # Decode and save certificate
    echo "$CERT" | base64 -d > "$CERT_FILE"

    # Decode and save private key
    echo "$KEY" | base64 -d > "$KEY_FILE"

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

# Decode and save certificate
echo "$CERT" | base64 -d > "$CERT_FILE"

# Decode and save private key
echo "$KEY" | base64 -d > "$KEY_FILE"

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

echo "Done!"

# Always run DNS setup
source "./setup-scripts/dns_setup.sh"
