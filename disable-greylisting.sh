#!/bin/bash

# Disable greylisting which causes soft reject even with score 0

echo "=== Disable Rspamd Greylisting ==="
echo ""

# Detect directory
if [ -f "docker-compose.yml" ] && [ -d "config/rspamd" ]; then
    CONFIG_DIR="."
elif [ -d "config-generated" ]; then
    CONFIG_DIR="./config-generated"
else
    echo "Error: Cannot find config-generated directory"
    exit 1
fi

RSPAMD_LOCAL_D="$CONFIG_DIR/config/rspamd/local.d"
GREYLIST_CONF="$RSPAMD_LOCAL_D/greylist.conf"

# Create local.d directory if it doesn't exist
mkdir -p "$RSPAMD_LOCAL_D"

echo "Disabling greylisting module..."
cat > "$GREYLIST_CONF" << 'EOF'
# Disable greylisting module
# Greylisting causes temporary rejection ("soft reject") even for legitimate mail
# This is too aggressive for a new mail server
enabled = false;
EOF

echo ""
echo "Created greylist.conf:"
cat "$GREYLIST_CONF"
echo ""

echo "Restarting rspamd..."
cd "$CONFIG_DIR" 2>/dev/null || cd config-generated
sudo docker compose restart rspamd

echo ""
echo "Waiting for rspamd..."
sleep 3

echo ""
echo "Checking rspamd logs:"
sudo docker compose logs --tail=20 rspamd

echo ""
echo "=== Done! ==="
echo ""
echo "Greylisting has been disabled."
echo "Emails with score < 15 should now be accepted immediately."
echo ""
echo "Note: One email was already delivered successfully!"
echo "Check your inbox for message ID: 68f7b9674f357415f15386a6"
