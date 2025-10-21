#!/bin/bash

# Comprehensive ZoneMTA Database Configuration Diagnostic and Fix Script

set -e

echo "=== ZoneMTA Database Configuration Diagnostic and Fix ==="
echo ""

# Check if we're in the right directory
if [ ! -f ".env" ]; then
    echo "Error: .env file not found. Please run this script from the wildduck-dockerized directory."
    exit 1
fi

echo "Step 1: Checking MongoDB URL from .env"
echo "----------------------------------------"
source .env

MONGO_URL=${WILDDUCK_MONGO_URL:-mongodb://mongo:27017/wildduck}
echo "MongoDB URL: $MONGO_URL"

# Extract database name from MONGO_URL
DB_NAME=$(echo "$MONGO_URL" | sed 's/.*\///' | sed 's/?.*//')
echo "Expected database name: $DB_NAME"
echo ""

echo "Step 2: Checking ZoneMTA configuration files"
echo "---------------------------------------------"

CONFIG_DIR="./config-generated/config/zone-mta"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: ZoneMTA config directory not found at $CONFIG_DIR"
    echo "Please run setup.sh first."
    exit 1
fi

NEEDS_FIX=false

for DBS_FILE in "$CONFIG_DIR"/dbs-*.toml; do
    if [ -f "$DBS_FILE" ]; then
        echo ""
        echo "Checking $(basename "$DBS_FILE"):"
        echo "--------------------------------"
        cat "$DBS_FILE"
        echo ""

        CURRENT_MONGO=$(grep "^mongo =" "$DBS_FILE" | cut -d'"' -f2)
        CURRENT_SENDER=$(grep "^sender =" "$DBS_FILE" | cut -d'"' -f2)

        echo "Current mongo URL: $CURRENT_MONGO"
        echo "Current sender database: $CURRENT_SENDER"

        if [ "$CURRENT_SENDER" != "$DB_NAME" ]; then
            echo "✗ WRONG! sender should be '$DB_NAME' but is '$CURRENT_SENDER'"
            NEEDS_FIX=true
        else
            echo "✓ Correct"
        fi
    fi
done

if [ "$NEEDS_FIX" = true ]; then
    echo ""
    echo "Step 3: Fixing configuration"
    echo "-----------------------------"

    for DBS_FILE in "$CONFIG_DIR"/dbs-*.toml; do
        if [ -f "$DBS_FILE" ]; then
            echo "Updating $(basename "$DBS_FILE")..."
            sed -i.backup "s|^mongo = \".*\"|mongo = \"$MONGO_URL\"|" "$DBS_FILE"
            sed -i.backup "s|^sender = \".*\"|sender = \"$DB_NAME\"|" "$DBS_FILE"
        fi
    done

    echo ""
    echo "Configuration updated!"
    echo ""
    echo "New configurations:"
    for DBS_FILE in "$CONFIG_DIR"/dbs-*.toml; do
        if [ -f "$DBS_FILE" ]; then
            echo ""
            echo "$(basename "$DBS_FILE"):"
            cat "$DBS_FILE"
        fi
    done
else
    echo ""
    echo "✓ All configurations look correct!"
fi
echo ""

echo "Step 4: Checking Docker container status"
echo "-----------------------------------------"
cd ./config-generated/

ZONEMTA_RUNNING=$(sudo docker compose ps zonemta --format json 2>/dev/null | grep -c "running" || echo "0")

if [ "$ZONEMTA_RUNNING" -gt 0 ]; then
    echo "ZoneMTA container is running"
else
    echo "ZoneMTA container is NOT running"
fi
echo ""

echo "Step 5: Restarting ZoneMTA"
echo "--------------------------"
echo "Stopping ZoneMTA..."
sudo docker compose stop zonemta

echo "Starting ZoneMTA..."
sudo docker compose start zonemta

echo "Waiting for ZoneMTA to start..."
sleep 3

echo ""
echo "Step 6: Verifying ZoneMTA logs"
echo "-------------------------------"
echo "Last 20 lines of ZoneMTA logs:"
sudo docker compose logs --tail=20 zonemta

cd ../

echo ""
echo "=== Diagnostic Complete ==="
echo ""
echo "Summary:"
echo "  MongoDB URL: $MONGO_URL"
echo "  Database Name: $DB_NAME"
echo "  Config File: $CONFIG_FILE"
echo "  Sender Field: $(grep "^sender =" "$CONFIG_FILE" | cut -d'"' -f2)"
echo ""
echo "✓ ZoneMTA has been restarted."
echo ""
echo "Please try sending an email again."
echo ""
echo "If you still get the error, please share:"
echo "  1. The output above"
echo "  2. The full error message"
echo "  3. ZoneMTA logs: cd config-generated && sudo docker compose logs --tail=50 zonemta"
