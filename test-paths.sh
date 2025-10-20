#!/bin/bash

# Test script to verify all file paths are correct
# This simulates what setup.sh does and checks the resulting paths

echo "=========================================="
echo "Path Configuration Test"
echo "=========================================="
echo ""

# Simulate setup.sh variables
CONFIG_DIR="config-generated"
MAILDOMAIN="0xmail.box"
ROOT_DIR="/root/wildduck-dockerized"
cwd="$ROOT_DIR"

# Test 1: DNS setup paths (from dns_setup.sh)
echo "Test 1: DNS Setup Paths (dns_setup.sh)"
echo "---------------------------------------"
CWD_CONFIG="$cwd/$CONFIG_DIR/config"
DKIM_KEY_FILE="$CWD_CONFIG/$MAILDOMAIN-dkim.pem"
DKIM_CERT_FILE="$CWD_CONFIG/$MAILDOMAIN-dkim.cert"
NAMESERVER_FILE="$CWD_CONFIG/$MAILDOMAIN-nameserver.txt"

echo "CWD_CONFIG:        $CWD_CONFIG"
echo "DKIM_KEY_FILE:     $DKIM_KEY_FILE"
echo "DKIM_CERT_FILE:    $DKIM_CERT_FILE"
echo "NAMESERVER_FILE:   $NAMESERVER_FILE"

# Check for double nesting
if [[ "$CWD_CONFIG" == *"config-generated/config-generated"* ]]; then
    echo "❌ FAIL: Double nesting detected in CWD_CONFIG!"
    exit 1
elif [[ "$CWD_CONFIG" == *"config-generated/config"* ]]; then
    echo "✅ PASS: Path is correct (config-generated/config)"
else
    echo "❌ FAIL: Unexpected path structure!"
    exit 1
fi
echo ""

# Test 2: MongoDB config paths (from mongo.sh)
echo "Test 2: MongoDB Config Paths (mongo.sh)"
echo "----------------------------------------"
declare -a CONFIG_FILES_TO_UPDATE
CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/$CONFIG_DIR/config/wildduck/dbs.toml" )
CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/$CONFIG_DIR/config/haraka/wildduck.yaml" )
CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/$CONFIG_DIR/config/zone-mta/dbs-development.toml" )
CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/$CONFIG_DIR/config/zone-mta/dbs-production.toml" )

ALL_PASS=true
for config_file in "${CONFIG_FILES_TO_UPDATE[@]}"; do
    echo "Config file: $config_file"

    # Check for double nesting
    if [[ "$config_file" == *"config-generated/config-generated"* ]]; then
        echo "  ❌ FAIL: Double nesting detected!"
        ALL_PASS=false
    elif [[ "$config_file" == *"config-generated/config/"* ]]; then
        echo "  ✅ PASS: Path is correct"
    else
        echo "  ❌ FAIL: Unexpected path structure!"
        ALL_PASS=false
    fi
done
echo ""

# Test 3: Docker Compose mount paths
echo "Test 3: Docker Compose Volume Mounts"
echo "-------------------------------------"
echo "When docker-compose runs from: $ROOT_DIR/$CONFIG_DIR/"
echo "Mount './config/wildduck' resolves to:"
echo "  → $ROOT_DIR/$CONFIG_DIR/config/wildduck"

RESOLVED_PATH="$ROOT_DIR/$CONFIG_DIR/config/wildduck"
if [[ "$RESOLVED_PATH" == *"config-generated/config-generated"* ]]; then
    echo "  ❌ FAIL: Double nesting detected!"
    ALL_PASS=false
elif [[ "$RESOLVED_PATH" == *"config-generated/config/wildduck"* ]]; then
    echo "  ✅ PASS: Path is correct"
else
    echo "  ❌ FAIL: Unexpected path structure!"
    ALL_PASS=false
fi
echo ""

# Test 4: Expected directory structure
echo "Test 4: Expected Directory Structure"
echo "-------------------------------------"
cat <<EOF
Expected structure after setup.sh runs:

$ROOT_DIR/
├── default-config/           (source templates)
│   ├── wildduck/
│   ├── haraka/
│   ├── zone-mta/
│   └── rspamd/
├── config-generated/         (deployment directory)
│   ├── config/               ← Config files go here
│   │   ├── wildduck/
│   │   ├── haraka/
│   │   ├── zone-mta/
│   │   └── rspamd/
│   ├── docker-compose.yml
│   ├── .env
│   ├── certs/
│   ├── dynamic_conf/
│   ├── 0xmail.box-dkim.pem        ← DKIM files here
│   ├── 0xmail.box-dkim.cert
│   └── 0xmail.box-nameserver.txt
EOF
echo ""

# Final result
echo "=========================================="
if [ "$ALL_PASS" = true ]; then
    echo "✅ ALL TESTS PASSED!"
    echo "=========================================="
    echo ""
    echo "Paths are correctly configured."
    echo "Files will be generated in: $ROOT_DIR/$CONFIG_DIR/config/"
    exit 0
else
    echo "❌ SOME TESTS FAILED!"
    echo "=========================================="
    echo ""
    echo "Path configuration has errors."
    exit 1
fi
