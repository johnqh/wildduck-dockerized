#!/bin/bash

# This script updates all backend services deployed by setup_be.sh
# It preserves all data and configurations while updating container images to latest versions

# Define configuration directory
CONFIG_DIR="./backend-config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display colored messages
function print_message {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function print_warning {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function print_error {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display error messages and exit
function error_exit {
    print_error "$1"
    exit 1
}

# Check if backend-config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    error_exit "Backend configuration directory not found at $CONFIG_DIR. Please run setup_be.sh first."
fi

# Check if docker-compose.yml exists in backend-config
if [ ! -f "$CONFIG_DIR/docker-compose.yml" ]; then
    error_exit "docker-compose.yml not found in $CONFIG_DIR. Please run setup_be.sh first."
fi

print_message "Starting backend services update process..."

# Navigate to backend configuration directory
cd "$CONFIG_DIR" || error_exit "Failed to change directory to $CONFIG_DIR"

# Step 1: Stop all running backend containers
print_message "Stopping all backend containers..."
sudo docker compose down || error_exit "Failed to stop backend containers"

# Step 2: Pull latest images for all services
print_message "Pulling latest container images..."
sudo docker compose pull || error_exit "Failed to pull latest images"

# Step 3: Display version information for all images
print_message "Container image versions:"
echo "----------------------------------------"

# Function to get image digest or tag
function get_image_info {
    local image=$1
    local info=$(sudo docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}" | grep "$image" | head -1)
    if [ -n "$info" ]; then
        echo "$info"
    else
        echo "$image: Not found"
    fi
}

# List of services from docker-compose
SERVICES=(
    "johnqh/wildduck"
    "ghcr.io/zone-eu/zonemta-wildduck"
    "johnqh/haraka-plugin-wildduck"
    "nodemailer/rspamd"
    "mongo"
    "redis"
    "traefik"
)

for service in "${SERVICES[@]}"; do
    get_image_info "$service"
done

echo "----------------------------------------"

# Step 4: Recreate and start containers with new images
print_message "Starting backend services with updated images..."
sudo docker compose up -d || error_exit "Failed to start backend services"

# Step 5: Wait for services to be healthy
print_message "Waiting for services to become healthy..."
sleep 10

# Step 6: Verify all services are running
print_message "Verifying service status..."
RUNNING_CONTAINERS=$(sudo docker compose ps --format "table {{.Service}}\t{{.Status}}" 2>/dev/null)

if [ -z "$RUNNING_CONTAINERS" ]; then
    print_warning "Could not retrieve container status"
else
    echo "----------------------------------------"
    echo "Service Status:"
    echo "$RUNNING_CONTAINERS"
    echo "----------------------------------------"
fi

# Step 7: Check for any containers that are not running
NOT_RUNNING=$(sudo docker compose ps --format json 2>/dev/null | jq -r 'select(.State != "running") | .Service' 2>/dev/null)

if [ -n "$NOT_RUNNING" ]; then
    print_warning "The following services are not running:"
    echo "$NOT_RUNNING"
    print_warning "Please check the logs with: sudo docker compose logs <service-name>"
else
    print_message "All services are running successfully!"
fi

# Step 8: Clean up old unused images
print_message "Cleaning up old unused images..."
sudo docker image prune -f || print_warning "Failed to prune unused images (non-critical)"

# Return to original directory
cd .. || print_warning "Failed to return to original directory"

# Display summary
echo ""
echo "========================================"
print_message "Backend services update completed!"
echo "========================================"
echo ""
echo "Summary:"
echo "- All backend containers have been stopped"
echo "- Latest images have been pulled"
echo "- Containers have been recreated with new images"
echo "- All data and configurations have been preserved"
echo ""
echo "To check logs for any service:"
echo "  cd $CONFIG_DIR && sudo docker compose logs <service-name>"
echo ""
echo "To check overall status:"
echo "  cd $CONFIG_DIR && sudo docker compose ps"
echo ""

# Check if update_certs.sh exists and remind about certificate updates
if [ -f "./update_certs.sh" ]; then
    print_message "Note: SSL certificate update script (update_certs.sh) is still configured."
    print_message "It will continue to run weekly as scheduled."
fi

exit 0