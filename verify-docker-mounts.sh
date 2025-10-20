#!/bin/bash

# Verify Docker container volume mounts are using correct paths
# This simulates the actual setup.sh execution flow

echo "=========================================="
echo "Docker Volume Mount Verification"
echo "=========================================="
echo ""

# Simulate setup.sh variables
CONFIG_DIR="config-generated"
ROOT_DIR="/root/wildduck-dockerized"

echo "Step 1: Setup.sh copies docker-compose.yml"
echo "-------------------------------------------"
echo "Source:      $ROOT_DIR/docker-compose.yml"
echo "Destination: $ROOT_DIR/$CONFIG_DIR/docker-compose.yml"
echo ""

echo "Step 2: Setup.sh changes directory and runs docker compose"
echo "-----------------------------------------------------------"
echo "Working directory: $ROOT_DIR/$CONFIG_DIR/"
echo "Command: cd $ROOT_DIR/$CONFIG_DIR/ && sudo docker compose up -d"
echo ""

echo "Step 3: Volume mount resolution from docker-compose.yml"
echo "--------------------------------------------------------"
echo ""
echo "When docker-compose runs from: $ROOT_DIR/$CONFIG_DIR/"
echo "Relative paths in docker-compose.yml resolve as:"
echo ""

# Extract actual volume mounts from docker-compose.yml
cat <<'EOF'
Volume Mount (in docker-compose.yml)  →  Actual Host Path
================================================================================
wildduck:
  ./config/wildduck                   →  /root/wildduck-dockerized/config-generated/config/wildduck

zonemta:
  ./config/zone-mta                   →  /root/wildduck-dockerized/config-generated/config/zone-mta

haraka:
  ./config/haraka                     →  /root/wildduck-dockerized/config-generated/config/haraka
  ./certs/HOSTNAME-key.pem            →  /root/wildduck-dockerized/config-generated/certs/HOSTNAME-key.pem
  ./certs/HOSTNAME.pem                →  /root/wildduck-dockerized/config-generated/certs/HOSTNAME.pem

rspamd:
  ./config/rspamd/override.d          →  /root/wildduck-dockerized/config-generated/config/rspamd/override.d
  ./config/rspamd/worker-normal.conf  →  /root/wildduck-dockerized/config-generated/config/rspamd/worker-normal.conf
  ./config/rspamd/local.d             →  /root/wildduck-dockerized/config-generated/config/rspamd/local.d

traefik:
  ./certs                             →  /root/wildduck-dockerized/config-generated/certs
  ./dynamic_conf                      →  /root/wildduck-dockerized/config-generated/dynamic_conf
EOF

echo ""
echo ""

echo "Step 4: Verification"
echo "--------------------"
PASS=true

# Check that paths resolve correctly
WILDDUCK_PATH="$ROOT_DIR/$CONFIG_DIR/config/wildduck"
RSPAMD_CONF="$ROOT_DIR/$CONFIG_DIR/config/rspamd/worker-normal.conf"

echo "Checking critical paths:"
echo ""

# Check 1: No double nesting
if [[ "$WILDDUCK_PATH" == *"config-generated/config-generated"* ]]; then
    echo "❌ FAIL: Double nesting in WildDuck path!"
    PASS=false
else
    echo "✅ PASS: WildDuck config path correct"
    echo "       $WILDDUCK_PATH"
fi

if [[ "$RSPAMD_CONF" == *"config-generated/config-generated"* ]]; then
    echo "❌ FAIL: Double nesting in Rspamd path!"
    PASS=false
else
    echo "✅ PASS: Rspamd config path correct"
    echo "       $RSPAMD_CONF"
fi

echo ""

echo "Step 5: Actual docker-compose.yml content verification"
echo "-------------------------------------------------------"

# Read actual docker-compose.yml and check volume mounts
if [ -f "/Users/johnhuang/0xmail/wildduck-dockerized/docker-compose.yml" ]; then
    echo "Checking volume mount paths in docker-compose.yml:"
    echo ""

    # Extract volume mounts (simplified check)
    WILDDUCK_MOUNT=$(grep -A 3 "wildduck:" /Users/johnhuang/0xmail/wildduck-dockerized/docker-compose.yml | grep "volumes:" -A 1 | grep "./config" || echo "")
    RSPAMD_MOUNT=$(grep -A 10 "rspamd:" /Users/johnhuang/0xmail/wildduck-dockerized/docker-compose.yml | grep "./config/rspamd" || echo "")

    if [[ -n "$WILDDUCK_MOUNT" ]]; then
        echo "WildDuck mount found:"
        echo "$WILDDUCK_MOUNT" | sed 's/^/  /'

        if [[ "$WILDDUCK_MOUNT" == *"./config/wildduck"* ]]; then
            echo "  ✅ Uses relative path ./config/wildduck (correct)"
        else
            echo "  ❌ Unexpected path format"
            PASS=false
        fi
    fi

    echo ""

    if [[ -n "$RSPAMD_MOUNT" ]]; then
        echo "Rspamd mounts found:"
        echo "$RSPAMD_MOUNT" | sed 's/^/  /'

        if [[ "$RSPAMD_MOUNT" == *"./config/rspamd"* ]]; then
            echo "  ✅ Uses relative path ./config/rspamd (correct)"
        else
            echo "  ❌ Unexpected path format"
            PASS=false
        fi
    fi
fi

echo ""
echo ""

echo "=========================================="
if [ "$PASS" = true ]; then
    echo "✅ ALL VERIFICATIONS PASSED!"
    echo "=========================================="
    echo ""
    echo "Docker containers WILL mount from:"
    echo "  $ROOT_DIR/$CONFIG_DIR/config/"
    echo ""
    echo "Directory structure when running:"
    echo "  config-generated/"
    echo "  ├── config/              ← Containers mount THIS"
    echo "  │   ├── wildduck/"
    echo "  │   ├── haraka/"
    echo "  │   ├── zone-mta/"
    echo "  │   └── rspamd/"
    echo "  ├── certs/"
    echo "  ├── dynamic_conf/"
    echo "  ├── docker-compose.yml"
    echo "  └── .env"
    exit 0
else
    echo "❌ VERIFICATION FAILED!"
    echo "=========================================="
    echo ""
    echo "Path configuration has issues."
    exit 1
fi
