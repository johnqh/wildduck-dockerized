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

# Update the sender field
echo ""
echo "Updating sender field to: $DB_NAME"
sed -i "s|sender = \".*\"|sender = \"$DB_NAME\"|" "$CONFIG_FILE"

# Verify the change
echo ""
echo "New ZoneMTA database configuration:"
grep -E "^mongo =|^sender =" "$CONFIG_FILE"

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
