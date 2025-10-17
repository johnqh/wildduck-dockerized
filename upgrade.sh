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

# Step 1: Stop containers
print_step "Step 1/3: Stopping containers..."
sudo docker compose down
echo ""

# Step 2: Pull latest images
print_step "Step 2/3: Pulling latest container images..."
echo ""
sudo docker compose pull
echo ""

# Step 3: Start containers
print_step "Step 3/3: Starting containers with new images..."
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
print_info "Configuration files were not modified."
echo ""
print_info "Useful commands:"
echo "  View logs:           cd $CONFIG_DIR && sudo docker compose logs -f <service>"
echo "  Restart a service:   cd $CONFIG_DIR && sudo docker compose restart <service>"
echo "  Check versions:      ./versions.sh"
echo ""

exit 0
