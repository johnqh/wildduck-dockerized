#!/bin/bash

# FINAL FIX: Change [main] to [message] in connection.ini
# Haraka code looks for cfg.message.greeting, not cfg.main.greeting!

echo "=== FINAL Haraka Greeting Fix ==="
echo ""

# Get hostname
HOSTNAME=$(grep -E "EMAIL_DOMAIN|MAILDOMAIN" .env 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d '"' || echo "0xmail.box")

echo "Hostname: $HOSTNAME"
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

echo "Step 1: Fixing connection.ini section"
echo "--------------------------------------"
echo ""
echo "Current connection.ini:"
cat "$CONNECTION_INI"
echo ""

# Replace [main] with [message]
sed -i 's/^\[main\]/[message]/' "$CONNECTION_INI"

# Ensure greeting is set
if ! grep -q "^greeting=" "$CONNECTION_INI"; then
    sed -i "/^\[message\]/a greeting=$HOSTNAME ESMTP Haraka" "$CONNECTION_INI"
fi

echo "Updated connection.ini:"
cat "$CONNECTION_INI"
echo ""

echo "Step 2: Restarting Haraka"
echo "-------------------------"

cd "$CONFIG_DIR" 2>/dev/null || cd config-generated

sudo docker compose restart haraka

echo ""
echo "Waiting for Haraka to start..."
sleep 5

echo ""
echo "Step 3: Checking logs"
echo "---------------------"
sudo docker compose logs --tail=30 haraka

echo ""
echo "=== Fix Complete ==="
echo ""
echo "The connection.ini now has [message] section (not [main])"
echo "Haraka looks for cfg.message.greeting, which should now work!"
echo ""
echo "Try sending an email. The crash should be FINALLY fixed!"
echo ""
echo "Watch logs:"
echo "  sudo docker compose logs -f haraka"
