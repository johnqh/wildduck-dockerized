#!/bin/bash

# Add [max] section with line_length to connection.ini
# These belong in [max], not [message]!

echo "=== Fix [max] Section in connection.ini ==="
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

# Remove line_length from [message] section if it exists there
sed -i '/^; Maximum line length for SMTP commands/d' "$CONNECTION_INI"
sed -i '/^line_length=.*$/d' "$CONNECTION_INI"
sed -i '/^; Maximum line length for message data/d' "$CONNECTION_INI"
sed -i '/^data_line_length=.*$/d' "$CONNECTION_INI"

# Check if [max] section already exists
if grep -q "^\[max\]" "$CONNECTION_INI"; then
    echo "[max] section already exists"
else
    echo "Adding [max] section with line_length settings..."
    # Add [max] section after [message] section, before [uuid]
    sed -i '/^\[uuid\]/i [max]\n; Maximum size and length limits\n; Maximum email size in bytes (default: 26214400 = 25MB)\nbytes=26214400\n; Maximum MIME parts (DoS protection, default: 1000)\nmime_parts=1000\n; Maximum line length for SMTP commands (default: 512)\nline_length=512\n; Maximum line length for message data (default: 992)\ndata_line_length=992\n' "$CONNECTION_INI"
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
sudo docker compose logs --tail=30 haraka

echo ""
echo "=== Done! ==="
echo "The [max] section has been added with line_length settings"
echo "Haraka looks for cfg.max.line_length (not cfg.message.line_length)"
echo ""
echo "Try sending an email - the crash should be FINALLY fixed!"
