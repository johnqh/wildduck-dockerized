#!/bin/bash

# Script to fix CORS issues in deployed WildDuck instance

echo "Searching for WildDuck API configuration..."

# Find the api.toml file in common locations
API_CONFIG_PATHS=(
    "./backend-config/config-generated/wildduck/api.toml"
    "./config-generated/config-generated/wildduck/api.toml"
    "/opt/wildduck/config/api.toml"
    "/etc/wildduck/api.toml"
)

FOUND_CONFIG=""

for path in "${API_CONFIG_PATHS[@]}"; do
    if [ -f "$path" ]; then
        FOUND_CONFIG="$path"
        echo "Found configuration at: $path"
        break
    fi
done

if [ -z "$FOUND_CONFIG" ]; then
    echo "Could not find api.toml configuration file."
    echo "Please manually locate your WildDuck API configuration file and add the following CORS section:"
    echo ""
    echo "[cors]"
    echo "origins = [\"http://localhost:5173\", \"*\"]"
    echo ""
    echo "Then restart your WildDuck service."
    exit 1
fi

echo "Backing up original configuration..."
cp "$FOUND_CONFIG" "$FOUND_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"

echo "Updating CORS configuration..."

# Check if CORS section already exists
if grep -q "^\[cors\]" "$FOUND_CONFIG"; then
    echo "CORS section already exists. Please manually update the origins."
    echo "Add or modify: origins = [\"http://localhost:5173\", \"*\"]"
else
    # Add CORS section if it doesn't exist
    if grep -q "# \[cors\]" "$FOUND_CONFIG"; then
        # Uncomment existing commented CORS section
        sed -i 's/# \[cors\]/[cors]/' "$FOUND_CONFIG"
        sed -i 's/# origins = \["\*"\]/origins = ["http:\/\/localhost:5173", "*"]/' "$FOUND_CONFIG"
    else
        # Add new CORS section at the end
        echo "" >> "$FOUND_CONFIG"
        echo "[cors]" >> "$FOUND_CONFIG"
        echo "origins = [\"http://localhost:5173\", \"*\"]" >> "$FOUND_CONFIG"
    fi
    echo "CORS configuration added successfully!"
fi

echo ""
echo "Configuration updated. Now restart your WildDuck service:"
echo ""
echo "# If using Docker Compose:"
echo "cd $(dirname "$FOUND_CONFIG")/../.."
echo "docker compose restart wildduck"
echo ""
echo "# Or if using systemd:"
echo "sudo systemctl restart wildduck"

echo ""
echo "Backup saved at: $FOUND_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"