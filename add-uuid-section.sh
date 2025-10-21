#!/bin/bash

# Add [uuid] section to connection.ini to fix banner_chars error

echo "=== Add UUID Section to connection.ini ==="
echo ""

# Detect directory
if [ -f "docker-compose.yml" ] && [ -d "config/haraka" ]; then
    CONFIG_DIR="."
elif [ -d "config-generated" ]; then
    CONFIG_DIR="./config-generated"
else
    echo "Error: Cannot find config-generated directory"
    exit 1
fi

CONNECTION_INI="$CONFIG_DIR/config/haraka/connection.ini"

echo "Current connection.ini:"
cat "$CONNECTION_INI"
echo ""

# Check if [uuid] section already exists
if grep -q "^\[uuid\]" "$CONNECTION_INI"; then
    echo "[uuid] section already exists"
else
    echo "Adding [uuid] section..."
    # Add [uuid] section before [haproxy] section
    sed -i '/^\[haproxy\]/i [uuid]\n; Show UUID in banner (optional, can be commented out)\n; banner_chars=8\n' "$CONNECTION_INI"
fi

echo ""
echo "Updated connection.ini:"
cat "$CONNECTION_INI"
echo ""

echo "Restarting Haraka..."
cd "$CONFIG_DIR" 2>/dev/null || cd config-generated
sudo docker compose restart haraka

echo ""
echo "Waiting for Haraka..."
sleep 5

echo ""
echo "Checking logs:"
sudo docker compose logs --tail=20 haraka

echo ""
echo "=== Done! ==="
echo "The [uuid] section has been added."
echo "This should fix the 'banner_chars' error."
