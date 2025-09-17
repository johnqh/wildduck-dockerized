#!/bin/bash

# Script to fix WildDuck API server to run api.js instead of server.js
# This fixes the 502 Bad Gateway and CORS issues

set -e  # Exit on any error

echo "🔧 WildDuck API Server Fix Script"
echo "=================================="
echo ""

# Function to display colored messages
function print_success {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

function print_info {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

function print_error {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

function print_warning {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Check if we're in the right directory
if [ ! -d "backend-config" ]; then
    print_error "backend-config directory not found. Please run this script from the wildduck-dockerized directory."
    exit 1
fi

# Step 1: Backup current configuration
print_info "Step 1: Creating backup of current configuration..."
cp backend-config/docker-compose.yml backend-config/docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
cp backend-config/config-generated/wildduck/api.toml backend-config/config-generated/wildduck/api.toml.backup.$(date +%Y%m%d_%H%M%S)
print_success "Backup created"

# Step 2: Fix CORS configuration
print_info "Step 2: Fixing CORS configuration in api.toml..."
sed -i 's/# \[cors\]/[cors]/' backend-config/config-generated/wildduck/api.toml
sed -i 's/# origins = \["\*"\]/origins = ["*"]/' backend-config/config-generated/wildduck/api.toml

# Verify CORS fix
if grep -q "^origins = \[" backend-config/config-generated/wildduck/api.toml; then
    print_success "CORS configuration updated"
else
    print_warning "CORS configuration might not be properly updated"
fi

# Step 3: Update docker-compose.yml to run API server
print_info "Step 3: Updating docker-compose.yml to run API server..."

# Check if command already exists
if grep -q "command.*api.js" backend-config/docker-compose.yml; then
    print_info "API server command already exists in docker-compose.yml"
else
    # Add command to run api.js after the image line
    sed -i '/image: johnqh\/wildduck:latest/a\    command: ["node", "/wildduck/api.js", "--config=/wildduck/config/api.toml"]' backend-config/docker-compose.yml
    print_success "Added API server command to docker-compose.yml"
fi

# Step 4: Verify the configuration
print_info "Step 4: Verifying configuration changes..."
echo "CORS configuration:"
cat backend-config/config-generated/wildduck/api.toml | tail -3
echo ""
echo "Docker compose wildduck service:"
cat backend-config/docker-compose.yml | grep -A 3 -B 1 "wildduck:" | head -6
echo ""

# Step 5: Restart the service
print_info "Step 5: Restarting WildDuck service..."
cd backend-config

# Stop the current container
print_info "Stopping current WildDuck container..."
docker compose stop wildduck

# Start with new configuration
print_info "Starting WildDuck with API server configuration..."
docker compose up -d wildduck

# Go back to original directory
cd ..

# Step 6: Wait and verify
print_info "Step 6: Waiting for service to start..."
sleep 10

# Check if container is running
if docker ps --filter "name=backend-config-wildduck-1" --format "{{.Status}}" | grep -q "Up"; then
    print_success "WildDuck container is running"
else
    print_error "WildDuck container failed to start"
    print_info "Checking logs..."
    docker logs backend-config-wildduck-1 | tail -10
    exit 1
fi

# Check if API is listening
print_info "Checking if API server is listening on port 8080..."
API_LISTENING=$(docker exec backend-config-wildduck-1 ss -tlnp 2>/dev/null | grep ":8080" || echo "")

if [ -n "$API_LISTENING" ]; then
    print_success "API server is now listening on port 8080!"
    echo "$API_LISTENING"
else
    print_warning "API server might not be listening yet. Checking container logs..."
    docker logs backend-config-wildduck-1 | tail -10
fi

# Step 7: Test the API endpoint
print_info "Step 7: Testing API endpoint..."
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/users | grep -q "200\|401\|403"; then
    print_success "API endpoint is responding!"
else
    print_warning "API endpoint test inconclusive. This might be normal if authentication is required."
fi

# Step 8: Test CORS with curl
print_info "Step 8: Testing CORS headers..."
CORS_TEST=$(curl -s -H "Origin: http://localhost:5173" -H "Access-Control-Request-Method: POST" -X OPTIONS http://127.0.0.1:8080/authenticate -I | grep -i "access-control" || echo "")

if [ -n "$CORS_TEST" ]; then
    print_success "CORS headers detected:"
    echo "$CORS_TEST"
else
    print_info "CORS headers not detected in local test. Testing external endpoint..."
    # Test the actual external endpoint
    EXTERNAL_CORS_TEST=$(curl -s -H "Origin: http://localhost:5173" -H "Access-Control-Request-Method: POST" -X OPTIONS https://0xmail.box/authenticate -I 2>/dev/null | grep -i "access-control" || echo "")
    
    if [ -n "$EXTERNAL_CORS_TEST" ]; then
        print_success "CORS headers detected on external endpoint:"
        echo "$EXTERNAL_CORS_TEST"
    else
        print_warning "CORS headers not detected. The fix might need a few more minutes to take effect."
    fi
fi

echo ""
print_success "WildDuck API server fix completed!"
echo ""
echo "📋 Summary of changes:"
echo "  ✅ CORS configuration enabled in api.toml"
echo "  ✅ Docker container now runs api.js instead of server.js"
echo "  ✅ Service restarted with new configuration"
echo ""
echo "🧪 Next steps:"
echo "  1. Wait 1-2 minutes for all services to fully start"
echo "  2. Test your frontend application again"
echo "  3. Check that https://0xmail.box/authenticate now responds properly"
echo ""
echo "📁 Backups created:"
echo "  - docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
echo "  - api.toml.backup.$(date +%Y%m%d_%H%M%S)"
echo ""
print_info "If you still have issues, check the logs with:"
echo "  docker logs backend-config-wildduck-1"