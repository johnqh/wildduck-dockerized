#!/bin/bash

# Adjust Rspamd spam score thresholds to be more lenient

echo "=== Adjust Rspamd Thresholds ==="
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
ACTIONS_CONF="$RSPAMD_LOCAL_D/actions.conf"

# Create local.d directory if it doesn't exist
mkdir -p "$RSPAMD_LOCAL_D"

echo "Creating/updating actions.conf with lenient thresholds..."
cat > "$ACTIONS_CONF" << 'EOF'
# Action thresholds for spam filtering
# Lower scores = more lenient, Higher scores = more strict
#
# Score progression should be: greylist < add_header < reject
#
# Current settings are lenient for testing/development
# Increase these values for production use

actions {
    # Reject emails with spam score >= 20 (was ~15 default)
    reject = 20;

    # Add spam headers at score >= 12 (was ~6 default)
    add_header = 12;

    # Greylist (soft reject) at score >= 15 (was ~10 default)
    # This causes temporary rejection with "try again later"
    greylist = 15;
}
EOF

echo ""
echo "Created actions.conf:"
cat "$ACTIONS_CONF"
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
echo "New thresholds:"
echo "  - Greylist (soft reject): >= 15 (was ~10)"
echo "  - Add spam header: >= 12 (was ~6)"
echo "  - Reject: >= 20 (was ~15)"
echo ""
echo "Your email with score 9.7 should now be accepted!"
echo ""
echo "Try sending another test email from Yahoo."
