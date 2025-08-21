#!/bin/bash

# This script displays version information for all running containers
# It works with both setup.sh and setup_be.sh deployments

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display colored messages
function print_header {
    echo -e "${CYAN}$1${NC}"
}

function print_service {
    echo -e "${GREEN}$1${NC}"
}

function print_error {
    echo -e "${RED}[ERROR]${NC} $1"
}

function print_warning {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check which config directory exists
function find_config_dir {
    if [ -d "./config-generated" ] && [ -f "./config-generated/docker-compose.yml" ]; then
        echo "./config-generated"
    elif [ -d "./backend-config" ] && [ -f "./backend-config/docker-compose.yml" ]; then
        echo "./backend-config"
    else
        echo ""
    fi
}

# Function to get container version info
function get_container_version {
    local container_name=$1
    local container_id=$(sudo docker ps --filter "name=$container_name" --format "{{.ID}}" 2>/dev/null | head -1)
    
    if [ -z "$container_id" ]; then
        echo "Not running"
        return
    fi
    
    # Get image info
    local image_info=$(sudo docker inspect $container_id --format='{{.Config.Image}}' 2>/dev/null)
    local created=$(sudo docker inspect $container_id --format='{{.Created}}' 2>/dev/null | cut -d'T' -f1)
    
    echo "$image_info (created: $created)"
}

# Function to get detailed version from inside container if possible
function get_app_version {
    local container_name=$1
    local service=$2
    local version_output=""
    
    case $service in
        "wildduck")
            version_output=$(sudo docker exec $container_name node -e "console.log(require('/wildduck/package.json').version)" 2>/dev/null || echo "N/A")
            ;;
        "wildduck-webmail")
            version_output=$(sudo docker exec $container_name node -e "console.log(require('/app/package.json').version)" 2>/dev/null || echo "N/A")
            ;;
        "zonemta")
            version_output=$(sudo docker exec $container_name node -e "console.log(require('/app/package.json').version)" 2>/dev/null || echo "N/A")
            ;;
        "haraka")
            version_output=$(sudo docker exec $container_name haraka -v 2>/dev/null | head -1 || echo "N/A")
            ;;
        "rspamd")
            version_output=$(sudo docker exec $container_name rspamd --version 2>/dev/null | head -1 || echo "N/A")
            ;;
        "mongo")
            version_output=$(sudo docker exec $container_name mongod --version 2>/dev/null | grep "db version" | awk '{print $3}' || echo "N/A")
            ;;
        "redis")
            version_output=$(sudo docker exec $container_name redis-server --version 2>/dev/null | awk '{print $3}' | cut -d'=' -f2 || echo "N/A")
            ;;
        "traefik")
            version_output=$(sudo docker exec $container_name traefik version 2>/dev/null | grep Version | awk '{print $2}' || echo "N/A")
            ;;
    esac
    
    echo "$version_output"
}

# Main execution
echo ""
print_header "============================================"
print_header "   WildDuck Dockerized - Container Versions"
print_header "============================================"
echo ""

# Find configuration directory
CONFIG_DIR=$(find_config_dir)

if [ -z "$CONFIG_DIR" ]; then
    print_error "No configuration directory found. Please run setup.sh or setup_be.sh first."
    exit 1
fi

print_header "Configuration directory: $CONFIG_DIR"
echo ""

# Check if Docker is running
if ! sudo docker info >/dev/null 2>&1; then
    print_error "Docker is not running or you don't have permission to access it."
    exit 1
fi

# Get project name from directory
PROJECT_NAME=$(basename $(cd "$CONFIG_DIR" && pwd) | sed 's/[^a-zA-Z0-9]//g')

# Get all running containers for this project
print_header "Fetching container information..."
echo ""

# Define services to check
declare -A services=(
    ["wildduck"]="WildDuck"
    ["wildduck-webmail"]="WildDuck Webmail"
    ["zonemta"]="ZoneMTA"
    ["haraka"]="Haraka"
    ["rspamd"]="Rspamd"
    ["mongo"]="MongoDB"
    ["redis"]="Redis"
    ["traefik"]="Traefik"
)

# Display version information
echo "----------------------------------------"
printf "%-20s %-50s %-20s\n" "SERVICE" "IMAGE" "APP VERSION"
echo "----------------------------------------"

for service_key in wildduck wildduck-webmail zonemta haraka rspamd mongo redis traefik; do
    service_name=${services[$service_key]}
    
    # Try different container name patterns
    container_found=false
    for pattern in "${CONFIG_DIR##*/}-${service_key}-1" "${CONFIG_DIR##*/}_${service_key}_1" "${service_key}"; do
        container_id=$(sudo docker ps --filter "name=$pattern" --format "{{.ID}}" 2>/dev/null | head -1)
        
        if [ -n "$container_id" ]; then
            container_found=true
            container_name=$(sudo docker ps --filter "id=$container_id" --format "{{.Names}}" 2>/dev/null)
            image=$(sudo docker inspect $container_id --format='{{.Config.Image}}' 2>/dev/null)
            app_version=$(get_app_version $container_name $service_key)
            
            printf "%-20s %-50s %-20s\n" "$service_name" "$image" "$app_version"
            break
        fi
    done
    
    if [ "$container_found" = false ]; then
        printf "%-20s %-50s %-20s\n" "$service_name" "Not running" "-"
    fi
done

echo "----------------------------------------"
echo ""

# Show summary statistics
RUNNING_COUNT=$(sudo docker ps --format "{{.Names}}" | grep -E "(wildduck|zonemta|haraka|rspamd|mongo|redis|traefik)" | wc -l)
TOTAL_CONTAINERS=$(sudo docker ps --format "{{.Names}}" | wc -l)

print_header "Summary:"
echo "  Services running: $RUNNING_COUNT"
echo "  Total containers: $TOTAL_CONTAINERS"
echo ""

# Show Docker and Docker Compose versions
print_header "System Information:"
echo -n "  Docker version: "
sudo docker version --format '{{.Server.Version}}' 2>/dev/null || echo "N/A"
echo -n "  Docker Compose version: "
sudo docker compose version --short 2>/dev/null || sudo docker-compose version --short 2>/dev/null || echo "N/A"
echo ""

# Show last update time if available
if [ -f "$CONFIG_DIR/docker-compose.yml" ]; then
    LAST_MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$CONFIG_DIR/docker-compose.yml" 2>/dev/null || \
                    stat -c "%y" "$CONFIG_DIR/docker-compose.yml" 2>/dev/null | cut -d' ' -f1-2)
    if [ -n "$LAST_MODIFIED" ]; then
        echo "  Config last modified: $LAST_MODIFIED"
    fi
fi

echo ""
print_header "Useful commands:"
echo "  View logs:        cd $CONFIG_DIR && sudo docker compose logs -f <service>"
echo "  Restart service:  cd $CONFIG_DIR && sudo docker compose restart <service>"
echo "  Update services:  ./update_be.sh (for backend) or ./update.sh (for full stack)"
echo ""

exit 0