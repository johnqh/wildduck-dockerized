#!/bin/bash

# Fix Haraka SMTP greeting - update smtpgreeting file
# This is the REAL file Haraka uses for the SMTP banner!

echo "=== Fix Haraka SMTP Greeting (smtpgreeting file) ==="
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

SMTPGREETING="$CONFIG_DIR/config/haraka/smtpgreeting"

echo "Step 1: Checking current smtpgreeting file"
echo "-------------------------------------------"

if [ -f "$SMTPGREETING" ]; then
    echo "Current content:"
    cat "$SMTPGREETING"
    echo ""
else
    echo "✗ smtpgreeting file not found at: $SMTPGREETING"
    exit 1
fi

echo ""
echo "Step 2: Updating smtpgreeting file"
echo "-----------------------------------"

echo "$HOSTNAME ESMTP Haraka" > "$SMTPGREETING"

echo "✓ Updated smtpgreeting file"
echo ""
echo "New content:"
cat "$SMTPGREETING"
echo ""

echo "Step 3: Restarting Haraka"
echo "-------------------------"

cd "$CONFIG_DIR" 2>/dev/null || cd config-generated

sudo docker compose restart haraka

echo ""
echo "Waiting for Haraka to start..."
sleep 3

echo ""
echo "Step 4: Checking logs"
echo "---------------------"
echo "Last 20 lines:"
sudo docker compose logs --tail=20 haraka

echo ""
echo "=== Fix Complete ==="
echo ""
echo "The smtpgreeting file has been updated with: $HOSTNAME ESMTP Haraka"
echo ""
echo "Try sending an email now. The crash should be fixed!"
echo ""
echo "Watch logs in real-time:"
echo "  sudo docker compose logs -f haraka"
