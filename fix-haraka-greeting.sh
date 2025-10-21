#!/bin/bash

# Fix Haraka SMTP greeting configuration
# Fixes the "Cannot read properties of undefined (reading 'greeting')" error

set -e

echo "=== Haraka Greeting Configuration Fix ==="
echo ""

# Get hostname
if [ -f ".env" ]; then
    source .env
    HOSTNAME=${EMAIL_DOMAIN:-0xmail.box}
else
    HOSTNAME="0xmail.box"
fi

echo "Hostname: $HOSTNAME"
echo ""

# Check if config-generated exists
if [ ! -d "./config-generated/config/haraka" ]; then
    echo "Error: config-generated/config/haraka directory not found"
    echo "Please run setup.sh first"
    exit 1
fi

CONNECTION_INI="./config-generated/config/haraka/connection.ini"

echo "Step 1: Checking connection.ini"
echo "--------------------------------"

if [ ! -f "$CONNECTION_INI" ]; then
    echo "✗ connection.ini not found"
    echo "  Creating new connection.ini..."

    cat > "$CONNECTION_INI" << EOF
[main]
; SMTP greeting banner shown to connecting clients
greeting=$HOSTNAME ESMTP Haraka

[haproxy]
; HAProxy PROXY protocol support
; List of IP addresses that are allowed to use the PROXY protocol
; Leave empty if not using HAProxy
hosts=
EOF

    echo "✓ Created connection.ini"
else
    echo "✓ connection.ini exists"

    # Check if it has a greeting
    if grep -q "^greeting=" "$CONNECTION_INI"; then
        CURRENT_GREETING=$(grep "^greeting=" "$CONNECTION_INI" | cut -d'=' -f2-)
        echo "  Current greeting: $CURRENT_GREETING"

        # Update to use correct hostname
        sed -i "s|^greeting=.*|greeting=$HOSTNAME ESMTP Haraka|" "$CONNECTION_INI"
        echo "  ✓ Updated greeting to: $HOSTNAME ESMTP Haraka"
    else
        # Check if [main] section exists
        if grep -q "^\[main\]" "$CONNECTION_INI"; then
            echo "  [main] section exists but no greeting"
            # Add greeting after [main]
            sed -i "/^\[main\]/a greeting=$HOSTNAME ESMTP Haraka" "$CONNECTION_INI"
            echo "  ✓ Added greeting to [main] section"
        else
            echo "  No [main] section found"
            # Add [main] section at the beginning
            echo "[main]" > "$CONNECTION_INI.tmp"
            echo "greeting=$HOSTNAME ESMTP Haraka" >> "$CONNECTION_INI.tmp"
            echo "" >> "$CONNECTION_INI.tmp"
            cat "$CONNECTION_INI" >> "$CONNECTION_INI.tmp"
            mv "$CONNECTION_INI.tmp" "$CONNECTION_INI"
            echo "  ✓ Added [main] section with greeting"
        fi
    fi
fi

echo ""

# Show the current configuration
echo "Step 2: Verifying configuration"
echo "--------------------------------"
echo ""
echo "Current connection.ini:"
cat "$CONNECTION_INI"
echo ""

# Restart Haraka
echo "Step 3: Restarting Haraka"
echo "-------------------------"

cd ./config-generated/

HARAKA_RUNNING=$(sudo docker compose ps haraka --format json 2>/dev/null | grep -c "running" || echo "0")

if [ "$HARAKA_RUNNING" -gt 0 ]; then
    echo "Stopping Haraka..."
    sudo docker compose stop haraka

    echo "Starting Haraka..."
    sudo docker compose start haraka

    echo "Waiting for Haraka to start..."
    sleep 3

    echo "✓ Haraka restarted"
else
    echo "Haraka is not running, starting it..."
    sudo docker compose up -d haraka

    echo "Waiting for Haraka to start..."
    sleep 3

    echo "✓ Haraka started"
fi

echo ""

# Check logs
echo "Step 4: Checking Haraka logs"
echo "----------------------------"
echo ""
echo "Last 15 lines of Haraka logs:"
sudo docker compose logs --tail=15 haraka

cd ..

echo ""
echo "=== Fix Complete ==="
echo ""
echo "The Haraka greeting has been configured."
echo ""
echo "To test, try sending an email to your domain."
echo "Watch logs in real-time:"
echo "  cd config-generated && sudo docker compose logs -f haraka"
echo ""
echo "You should no longer see the 'Cannot read properties of undefined' error."
echo ""
