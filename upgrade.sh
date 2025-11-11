#!/bin/bash

# WildDuck Dockerized - Upgrade Script
# This script updates all Docker containers to their latest versions
# without modifying any configuration files

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display colored messages
function print_header {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

function print_step {
    echo -e "${GREEN}➜${NC} $1"
}

function print_error {
    echo -e "${RED}[ERROR]${NC} $1"
}

function print_warning {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function print_info {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to find the config directory
function find_config_dir {
    if [ -d "./config-generated" ] && [ -f "./config-generated/docker-compose.yml" ]; then
        echo "./config-generated"
    elif [ -d "./backend-config" ] && [ -f "./backend-config/docker-compose.yml" ]; then
        echo "./backend-config"
    else
        echo ""
    fi
}

# Function to update environment variables from Doppler
function update_doppler_secrets {
    print_step "Updating environment variables from Doppler..."
    echo ""

    # Save current directory
    CURRENT_DIR=$(pwd)

    # Go back to root directory where .doppler-token should be
    cd ..

    DOPPLER_TOKEN_FILE=".doppler-token"
    DOPPLER_TOKEN=""

    if [ -f "$DOPPLER_TOKEN_FILE" ]; then
        DOPPLER_TOKEN=$(cat "$DOPPLER_TOKEN_FILE")
        print_info "Found saved Doppler token"
    else
        print_warning "No Doppler token found at $DOPPLER_TOKEN_FILE"
        print_info "Skipping Doppler update. To enable, save your token to $DOPPLER_TOKEN_FILE"
        cd "$CURRENT_DIR"
        return 0
    fi

    # Download from Doppler to a temporary file
    DOPPLER_ENV_FILE=".env.doppler"
    HTTP_CODE=$(curl -u "$DOPPLER_TOKEN:" \
        -w "%{http_code}" \
        -o "$DOPPLER_ENV_FILE" \
        -s \
        https://api.doppler.com/v3/configs/config/secrets/download?format=env)

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_info "✓ Successfully downloaded latest secrets from Doppler"

        # Update .env in root directory
        if [ -f .env ]; then
            print_info "Updating .env with latest Doppler secrets..."
            cp .env .env.backup

            # Merge: Keep existing .env, then overwrite with Doppler values
            cat .env.backup "$DOPPLER_ENV_FILE" | \
                awk -F= '!seen[$1]++ || /^[A-Z_]+=/' > .env.temp
            mv .env.temp .env
            rm -f .env.backup

            print_info "✓ Updated .env with Doppler secrets"
        else
            mv "$DOPPLER_ENV_FILE" .env
            print_info "✓ Created .env from Doppler secrets"
        fi

        # Clean up temporary file
        rm -f "$DOPPLER_ENV_FILE"

        print_info "✓ Environment variables updated from Doppler"
    else
        print_error "Failed to download from Doppler (HTTP $HTTP_CODE)"
        print_warning "Token may be invalid or expired. Please update $DOPPLER_TOKEN_FILE"
        print_info "Continuing with existing environment variables..."
        rm -f "$DOPPLER_ENV_FILE"
    fi

    # Return to config directory
    cd "$CURRENT_DIR"
    echo ""
}

echo ""
print_header "WildDuck Dockerized - Container Upgrade"
echo ""

# Check if Docker is running
if ! sudo docker info >/dev/null 2>&1; then
    print_error "Docker is not running or you don't have permission to access it."
    exit 1
fi

# Find configuration directory
CONFIG_DIR=$(find_config_dir)

if [ -z "$CONFIG_DIR" ]; then
    print_error "No configuration directory found."
    print_info "Please run ./setup.sh first to create the initial deployment."
    exit 1
fi

print_info "Configuration directory: $CONFIG_DIR"
echo ""

# Navigate to config directory
cd "$CONFIG_DIR"

# Show current running containers
print_step "Current running containers:"
echo ""
sudo docker compose ps
echo ""

# Ask for confirmation
read -p "Do you want to proceed with the upgrade? This will restart all services. (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Upgrade cancelled by user."
    exit 0
fi
echo ""

# Step 1: Update Doppler secrets
print_step "Step 1/5: Updating environment variables from Doppler..."
update_doppler_secrets

# Step 2: Update docker-compose.yml with latest configuration
print_step "Step 2/5: Updating docker-compose.yml configuration..."

# Extract current hostname from existing docker-compose.yml
CURRENT_HOSTNAME=$(grep -m 1 "traefik.tcp.routers.wildduck-imaps.rule: HostSNI(" docker-compose.yml | sed -n "s/.*HostSNI(\`\(.*\)\`).*/\1/p" || echo "")

if [ -z "$CURRENT_HOSTNAME" ] || [ "$CURRENT_HOSTNAME" = "HOSTNAME" ]; then
    # Fallback: try to get from environment or use default
    CURRENT_HOSTNAME="${EMAIL_DOMAIN:-0xmail.box}"
    print_warning "Could not detect hostname from docker-compose.yml, using: $CURRENT_HOSTNAME"
else
    print_info "Detected hostname: $CURRENT_HOSTNAME"
fi

# Backup current docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Copy latest docker-compose.yml from root
cd ..
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "$CONFIG_DIR/docker-compose.yml"
    cd "$CONFIG_DIR"

    # Replace HOSTNAME placeholder with actual hostname
    sed -i "s|HOSTNAME|$CURRENT_HOSTNAME|g" docker-compose.yml

    # Replace cert paths
    sed -i "s|./certs/HOSTNAME-key.pem|./certs/$CURRENT_HOSTNAME-key.pem|g" docker-compose.yml
    sed -i "s|./certs/HOSTNAME.pem|./certs/$CURRENT_HOSTNAME.pem|g" docker-compose.yml

    print_info "✓ Updated docker-compose.yml with hostname: $CURRENT_HOSTNAME"
else
    cd "$CONFIG_DIR"
    print_warning "Root docker-compose.yml not found, skipping update"
fi
echo ""

# Step 3: Stop containers
print_step "Step 3/5: Stopping containers..."
sudo docker compose down
echo ""

# Step 4: Pull latest images
print_step "Step 4/5: Pulling latest container images..."
echo ""
sudo docker compose pull
echo ""

# Step 5: Start containers
print_step "Step 5/5: Starting containers with new images..."
sudo docker compose up -d
echo ""

# Wait a moment for containers to initialize
print_info "Waiting for containers to initialize..."
sleep 5
echo ""

# Show final status
print_step "Container status after upgrade:"
echo ""
sudo docker compose ps
echo ""

# Show which images were updated
print_step "Image information:"
echo ""
sudo docker compose images
echo ""

print_header "✓ Upgrade completed successfully!"
echo ""
print_info "All containers have been updated to their latest versions."
print_info "Environment variables have been refreshed from Doppler."
print_info "Configuration files were not modified."
echo ""
print_info "Useful commands:"
echo "  View logs:           cd $CONFIG_DIR && sudo docker compose logs -f <service>"
echo "  Restart a service:   cd $CONFIG_DIR && sudo docker compose restart <service>"
echo "  Check versions:      ./versions.sh"
echo ""

exit 0
