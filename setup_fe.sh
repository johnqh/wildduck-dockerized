
#!/bin/bash

# This script deploys the frontend (WildDuck Webmail) service.
# It prompts for API URL and API Token, then updates the webmail config
# and starts the Docker containers for the frontend components.

# Define directories for frontend configuration
FRONTEND_CONFIG_DIR="./frontend-generated"
DEFAULT_WEBMAIL_CONFIG_SOURCE="./default-config/wildduck-webmail/default.toml" # Path to the default webmail config
BASE_DOCKER_COMPOSE_SOURCE="./docker-compose.yml" # Assuming the base docker-compose.yml is here

# --- Functions ---

# Function to display error messages and exit
function error_exit {
    echo "Error: $1" >&2
    exit 1
}

# Function to clean up old configurations
function clean_up {
    echo "Cleaning up old frontend configuration files and folders..."
    read -p "Are you sure you want to remove the '$FRONTEND_CONFIG_DIR' directory? [Y/n] " yn
    case $yn in
        [Yy]* )
            sudo rm -rf "$FRONTEND_CONFIG_DIR" || error_exit "Failed to remove $FRONTEND_CONFIG_DIR"
            echo "Clean up complete."
            ;;
        [Nn]* )
            echo "No files and folders removed. Continuing with deployment..."
            ;;
        * )
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
        echo -e "Using HOSTNAME: $HOSTNAME"
    else
        read -p "Specify the HOSTNAME for your webmail (e.g., webmail.example.com): " HOSTNAME
    fi

    if [ -z "$HOSTNAME" ]; then
        error_exit "Hostname cannot be empty."
    fi
}

# Function to prepare frontend configuration directories and copy docker-compose
function prepare_config_dirs {
    echo "Preparing frontend configuration directories..."
    mkdir -p "$FRONTEND_CONFIG_DIR"/wildduck-webmail || error_exit "Failed to create $FRONTEND_CONFIG_DIR/wildduck-webmail"

    # Copy the default webmail config file
    if [ ! -f "$DEFAULT_WEBMAIL_CONFIG_SOURCE" ]; then
        error_exit "Default webmail config file not found at $DEFAULT_WEBMAIL_CONFIG_SOURCE. Please ensure it exists."
    fi
    cp "$DEFAULT_WEBMAIL_CONFIG_SOURCE" "$FRONTEND_CONFIG_DIR"/wildduck-webmail/default.toml || error_exit "Failed to copy default webmail config"

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

    # Modify the copied docker-compose.yml
    # Remove all services except wildduck-webmail and traefik
    # This is a bit more complex, we'll build a new docker-compose content
    TEMP_DOCKER_COMPOSE_CONTENT=$(mktemp)
    awk '/version:/,/wildduck-webmail:/ {print} /wildduck-webmail:/,/traefik:/ { if (!/wildduck-webmail:/ && !/traefik:/) next; print } /traefik:/,/^$/ {print}' "$BASE_DOCKER_COMPOSE_SOURCE" > "$TEMP_DOCKER_COMPOSE_CONTENT"

    # Now, filter out other services that might still be there if the awk pattern wasn't perfect
    # We only want 'wildduck-webmail', 'redis' (for frontend's own redis), and 'traefik'
    # Re-build the docker-compose.yml to only include necessary services
    echo "version: \"3.8\"" > "$FRONTEND_CONFIG_DIR"/docker-compose.yml
    echo "volumes:" >> "$FRONTEND_CONFIG_DIR"/docker-compose.yml
    echo "  redis:" >> "$FRONTEND_CONFIG_DIR"/docker-compose.yml # Frontend needs its own redis volume
    echo "  traefik:" >> "$FRONTEND_CONFIG_DIR"/docker-compose.yml # Traefik needs its own volume
    echo "services:" >> "$FRONTEND_CONFIG_DIR"/docker-compose.yml

    # Add redis service for frontend
    cat <<EOF >> "$FRONTEND_CONFIG_DIR"/docker-compose.yml
  redis:
    image: redis:alpine
    restart: unless-stopped
    volumes:
      - redis:/data
EOF

    # Add wildduck-webmail service
    awk '/wildduck-webmail:/,/labels:/ {print} /labels:/,/^$/ {print}' "$BASE_DOCKER_COMPOSE_SOURCE" >> "$FRONTEND_CONFIG_DIR"/docker-compose.yml
    
    # Add traefik service
    awk '/traefik:/,/^$/ {print}' "$BASE_DOCKER_COMPOSE_SOURCE" >> "$FRONTEND_CONFIG_DIR"/docker-compose.yml

    # Clean up temporary file
    rm "$TEMP_DOCKER_COMPOSE_CONTENT"

    # Adjust volume paths for copied configs in the newly built docker-compose.yml
    sed -i "s|./config/wildduck-webmail:/app/config|./wildduck-webmail:/app/config|g" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust webmail volume path"
    sed -i "s|./config/wildduck-webmail:/app/config|./wildduck-webmail:/app/config|g" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to adjust webmail volume path"
    sed -i "s|./certs:/etc/traefik/certs # Mount your certs directory/d" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || true # Remove certs mount from Traefik if present
    sed -i "s|./dynamic_conf:/etc/traefik/dynamic_conf:ro/d" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || true # Remove dynamic_conf mount if present

    # Ensure Traefik in frontend docker-compose is configured for Let's Encrypt for webmail
    MAILDOMAIN=$(echo "$HOSTNAME" | sed 's/^[^.]*\.//') # Extract domain from hostname
    if [ -z "$MAILDOMAIN" ]; then
        MAILDOMAIN=$HOSTNAME # Fallback if no subdomain
    fi
    sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.email=ACME_EMAIL\"|- \"--certificatesresolvers.letsencrypt.acme.email=webmaster@$MAILDOMAIN\"|g" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to set ACME_EMAIL in frontend Traefik"
    sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|- \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|g" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to set LE storage in frontend Traefik"
    sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|- \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|g" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to set LE tlschallenge in frontend Traefik"
    
    # Remove explicit 'tls: true' lines as certresolver implies TLS for webmail
    sed -i "/traefik.http.routers.wildduck-webmail.tls: true/d" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || true

    # Replace HOSTNAME placeholder in docker-compose.yml
    sed -i "s|HOSTNAME|$HOSTNAME|g" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to replace HOSTNAME in docker-compose.yml"

    # Prompt for API Token
    read -p "Enter the WildDuck API Token (from backend setup): " API_TOKEN
    if [ -z "$API_TOKEN" ]; then
        error_exit "API Token cannot be empty."
    fi
    sed -i "s|accessToken=\"\"|accessToken=\"$API_TOKEN\"|g" "$FRONTEND_CONFIG_DIR"/wildduck-webmail/default.toml || error_exit "Failed to update API Token in webmail config"

    # Prompt for API URL
    read -p "Enter the WildDuck API URL (e.g., https://mail.example.com/api): " API_URL
    if [ -z "$API_URL" ]; then
        error_exit "API URL cannot be empty."
    fi
    sed -i "s|url=\"http://wildduck:8080\"|url=\"$API_URL\"|g" "$FRONTEND_CONFIG_DIR"/wildduck-webmail/default.toml || error_exit "Failed to update API URL in webmail config"

    # Update Redis DB config for frontend (using its own Redis instance)
    # The default.toml has "redis="redis://redis:6379/5""
    # We just need to ensure it points to the local redis service within the frontend compose.
    # No change needed if it's already "redis://redis:6379/5" and a redis service exists.
    # If the user wants to specify a different DB, they can edit the default.toml manually.
    echo "Using default Redis configuration for frontend: redis://redis:6379/5"
    # Ensure the `depends_on` for redis is present for wildduck-webmail
    sed -i "/wildduck-webmail:/!b;n;/depends_on:/a\      - redis" "$FRONTEND_CONFIG_DIR"/docker-compose.yml || error_exit "Failed to add redis dependency to webmail service"


    # Update hostname in webmail config (service and u2f appId)
    sed -i "s|domain=\"example.com\"|domain=\"$MAILDOMAIN\"|" "$FRONTEND_CONFIG_DIR"/wildduck-webmail/default.toml || error_exit "Failed to update domain in webmail config"
    sed -i "s|appId=\"https://example.com\"|appId=\"https://$HOSTNAME\"|" "$FRONTEND_CONFIG_DIR"/wildduck-webmail/default.toml || error_exit "Failed to update u2f appId in webmail config"
    sed -i "s|hostname=\"example.com\"|hostname=\"$HOSTNAME\"|g" "$FRONTEND_CONFIG_DIR"/wildduck-webmail/default.toml || error_exit "Failed to update hostname in setup section of webmail config"


    echo "Frontend configurations applied."
}

# --- Main Script Execution ---

args=("$@")

clean_up
get_hostname "${args[@]}"
prepare_config_dirs
apply_frontend_configs

echo "Stopping any existing frontend containers..."
sudo docker compose -f "$FRONTEND_CONFIG_DIR"/docker-compose.yml down || echo "No existing frontend containers to stop."

echo "Deploying frontend services..."
cd "$FRONTEND_CONFIG_DIR" || error_exit "Failed to change directory to $FRONTEND_CONFIG_DIR"
sudo docker compose up -d || error_exit "Failed to deploy frontend service"
cd .. # Go back to original directory

echo "Frontend deployment complete! Access your webmail at https://$HOSTNAME"
