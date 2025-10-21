#!/bin/bash

# Add line_length and data_line_length to [message] section

echo "=== Fix Message Line Length in connection.ini ==="
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

# Check if line_length already exists
if grep -q "^line_length=" "$CONNECTION_INI"; then
    echo "line_length already exists"
else
    echo "Adding line_length and data_line_length to [message] section..."
    # Add after greeting line
    sed -i '/^greeting=/a ; Maximum line length for SMTP commands (default: 512)\nline_length=512\n; Maximum line length for message data (default: 992)\ndata_line_length=992' "$CONNECTION_INI"
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
echo "Added line_length=512 and data_line_length=992 to [message] section"
echo "This should fix the 'line_length' error at connection.js:398"
