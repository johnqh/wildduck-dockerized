#!/bin/bash

# Fix ZoneMTA database configuration
# This script ensures ZoneMTA uses the same database as WildDuck

set -e

echo "=== ZoneMTA Database Configuration Fix ==="
echo ""

# Check if we're in the right directory
if [ ! -f ".env" ]; then
    echo "Error: .env file not found. Please run this script from the wildduck-dockerized directory."
    exit 1
fi

# Source the .env file to get WILDDUCK_MONGO_URL
source .env

# Get the MongoDB URL
MONGO_URL=${WILDDUCK_MONGO_URL:-mongodb://mongo:27017/wildduck}

echo "MongoDB URL: $MONGO_URL"

# Extract database name from MONGO_URL
# Get the part after the last /, strip query parameters
DB_NAME=$(echo "$MONGO_URL" | sed 's/.*\///' | sed 's/?.*//')

echo "Database name: $DB_NAME"

# Check if config file exists
CONFIG_FILE="./config-generated/config/zone-mta/dbs-production.toml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: ZoneMTA config file not found at $CONFIG_FILE"
    echo "Please run setup.sh first."
    exit 1
fi

# Show current configuration
echo ""
echo "Current ZoneMTA database configuration:"
grep -E "^mongo =|^sender =" "$CONFIG_FILE"

# Update both development and production config files
echo ""
echo "Updating ZoneMTA database configuration files..."

for DBS_FILE in ./config-generated/config/zone-mta/dbs-*.toml; do
    if [ -f "$DBS_FILE" ]; then
        echo ""
        echo "Updating $(basename "$DBS_FILE")..."
        sed -i "s|mongo = \".*\"|mongo = \"$MONGO_URL\"|" "$DBS_FILE"
        sed -i "s|sender = \".*\"|sender = \"$DB_NAME\"|" "$DBS_FILE"

        echo "New configuration:"
        grep -E "^mongo =|^sender =" "$DBS_FILE"
    fi
done

echo ""
echo "✓ Configuration updated successfully!"
echo ""
echo "Restarting services..."

cd ./config-generated/
sudo docker compose restart zonemta
cd ../

echo ""
echo "✓ ZoneMTA has been restarted with the correct database configuration."
echo ""
echo "You can now try sending an email again."
