#!/bin/bash

# MongoDB Setup Script
# This script sets up a MongoDB container with external access enabled

set -e

# Configuration
CONTAINER_NAME="wildduck-mongo"
MONGO_VERSION="7.0"
MONGO_PORT="27017"
MONGO_ROOT_USER="admin"
MONGO_ROOT_PASSWORD="changeme"
MONGO_DATA_DIR="./mongodb_data"
NETWORK_NAME="wildduck-network"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}MongoDB Container Setup Script${NC}"
echo "================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Create network if it doesn't exist
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    echo -e "${YELLOW}Creating Docker network: $NETWORK_NAME${NC}"
    docker network create "$NETWORK_NAME"
fi

# Create data directory if it doesn't exist
if [ ! -d "$MONGO_DATA_DIR" ]; then
    echo -e "${YELLOW}Creating MongoDB data directory: $MONGO_DATA_DIR${NC}"
    mkdir -p "$MONGO_DATA_DIR"
fi

# Stop and remove existing container if it exists
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo -e "${YELLOW}Stopping and removing existing MongoDB container${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Run MongoDB container
echo -e "${GREEN}Starting MongoDB container...${NC}"
docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    -p "$MONGO_PORT:27017" \
    -v "$(pwd)/$MONGO_DATA_DIR:/data/db" \
    -e MONGO_INITDB_ROOT_USERNAME="$MONGO_ROOT_USER" \
    -e MONGO_INITDB_ROOT_PASSWORD="$MONGO_ROOT_PASSWORD" \
    --restart unless-stopped \
    "mongo:$MONGO_VERSION" \
    mongod --bind_ip_all

# Wait for MongoDB to be ready
echo -e "${YELLOW}Waiting for MongoDB to be ready...${NC}"
for i in {1..30}; do
    if docker exec "$CONTAINER_NAME" mongosh --eval "db.adminCommand('ping')" \
        -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" --authenticationDatabase admin \
        > /dev/null 2>&1; then
        echo -e "${GREEN}MongoDB is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Create WildDuck database and user
echo -e "${YELLOW}Creating WildDuck database and user...${NC}"
docker exec "$CONTAINER_NAME" mongosh \
    -u "$MONGO_ROOT_USER" \
    -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --eval "
        use wildduck;
        db.createUser({
            user: 'wildduck',
            pwd: 'wildduck',
            roles: [
                { role: 'readWrite', db: 'wildduck' },
                { role: 'dbAdmin', db: 'wildduck' }
            ]
        });
    " 2>/dev/null || echo "WildDuck user might already exist"

# Display connection information
echo ""
echo -e "${GREEN}MongoDB Setup Complete!${NC}"
echo "======================="
echo ""
echo "Connection Details:"
echo "-------------------"
echo "Host: localhost (or your server IP for external access)"
echo "Port: $MONGO_PORT"
echo ""
echo "Admin Credentials:"
echo "  Username: $MONGO_ROOT_USER"
echo "  Password: $MONGO_ROOT_PASSWORD"
echo ""
echo "WildDuck Database:"
echo "  Database: wildduck"
echo "  Username: wildduck"
echo "  Password: wildduck"
echo ""
echo "Connection strings:"
echo "  Admin: mongodb://$MONGO_ROOT_USER:$MONGO_ROOT_PASSWORD@localhost:$MONGO_PORT/admin"
echo "  WildDuck: mongodb://wildduck:wildduck@localhost:$MONGO_PORT/wildduck"
echo ""
echo "External Connection:"
echo "  Replace 'localhost' with your server's IP address to connect from external clients"
echo "  Example: mongodb://wildduck:wildduck@YOUR_SERVER_IP:$MONGO_PORT/wildduck"
echo ""
echo "Container Status:"
docker ps | grep "$CONTAINER_NAME"