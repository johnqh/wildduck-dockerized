#!/bin/bash

# Ultra-quick Haraka greeting fix - single command
# This adds the missing greeting configuration immediately

echo "=== Quick Haraka Greeting Fix ==="
echo ""

# Get hostname
HOSTNAME=$(grep -E "EMAIL_DOMAIN|MAILDOMAIN" .env 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d '"' || echo "0xmail.box")

echo "Hostname: $HOSTNAME"
echo ""

CONNECTION_INI="./config-generated/config/haraka/connection.ini"

# Check if file exists
if [ ! -f "$CONNECTION_INI" ]; then
    echo "Error: $CONNECTION_INI not found!"
    exit 1
fi

echo "Current connection.ini:"
cat "$CONNECTION_INI"
echo ""

# Check if greeting already exists
if grep -q "^greeting=" "$CONNECTION_INI"; then
    echo "Greeting already exists, updating it..."
    sed -i "s|^greeting=.*|greeting=$HOSTNAME ESMTP Haraka|" "$CONNECTION_INI"
else
    echo "Adding greeting to connection.ini..."
    # Check if [main] section exists
    if grep -q "^\[main\]" "$CONNECTION_INI"; then
        # Add after [main]
        sed -i "/^\[main\]/a greeting=$HOSTNAME ESMTP Haraka" "$CONNECTION_INI"
    else
        # Add [main] section at the top
        sed -i "1i [main]\ngreeting=$HOSTNAME ESMTP Haraka\n" "$CONNECTION_INI"
    fi
fi

echo ""
echo "New connection.ini:"
cat "$CONNECTION_INI"
echo ""

# Restart Haraka
echo "Restarting Haraka..."
cd config-generated
sudo docker compose restart haraka
echo ""
echo "✓ Done! Check logs:"
echo "  sudo docker compose logs -f haraka"
