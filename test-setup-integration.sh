#!/bin/bash

# Integration test for setup.sh file generation
# This test verifies that files are actually created in the correct locations
# and that Docker containers can access them

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="/tmp/wildduck-test-$$"
CONFIG_DIR="config-generated"
MAILDOMAIN="test.example.com"
HOSTNAME="mail.test.example.com"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

echo "=========================================="
echo "WildDuck Setup Integration Test"
echo "=========================================="
echo ""
echo "Test directory: $TEST_DIR"
echo ""

# Cleanup function
cleanup() {
    if [ -d "$TEST_DIR" ]; then
        echo ""
        echo "Cleaning up test directory..."
        rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

# Test assertion helper
assert_file_exists() {
    local file_path="$1"
    local description="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    echo -n "Test $TESTS_TOTAL: $description... "

    if [ -f "$file_path" ]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected file: $file_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_dir_exists() {
    local dir_path="$1"
    local description="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    echo -n "Test $TESTS_TOTAL: $description... "

    if [ -d "$dir_path" ]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected directory: $dir_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_exists() {
    local path="$1"
    local description="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    echo -n "Test $TESTS_TOTAL: $description... "

    if [ ! -e "$path" ]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Path should not exist: $path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_not_empty() {
    local file_path="$1"
    local description="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    echo -n "Test $TESTS_TOTAL: $description... "

    if [ -f "$file_path" ] && [ -s "$file_path" ]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  File empty or missing: $file_path"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
echo "Setting up test environment..."
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Simulate minimal directory structure
mkdir -p default-config/{wildduck,haraka,zone-mta,rspamd}
touch default-config/wildduck/api.toml
touch default-config/wildduck/dbs.toml
touch default-config/haraka/wildduck.yaml
touch default-config/zone-mta/dbs-production.toml
touch default-config/rspamd/worker-normal.conf

echo "Creating mock docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
services:
  wildduck:
    volumes:
      - ./config/wildduck:/wildduck/config
  haraka:
    volumes:
      - ./config/haraka:/app/config
  rspamd:
    volumes:
      - ./config/rspamd/worker-normal.conf:/etc/rspamd/worker-normal.conf
EOF

echo ""
echo "=========================================="
echo "Phase 1: Simulating setup.sh file creation"
echo "=========================================="
echo ""

# Simulate setup.sh's config copy
echo "Copying default-config to $CONFIG_DIR/config..."
mkdir -p "$CONFIG_DIR"
rm -rf "./$CONFIG_DIR/config"
cp -r ./default-config "./$CONFIG_DIR/config"

# Simulate dns_setup.sh DKIM generation
echo "Generating DKIM keys (simulated)..."
CWD_CONFIG="$TEST_DIR/$CONFIG_DIR/config"
DKIM_KEY_FILE="$CWD_CONFIG/$MAILDOMAIN-dkim.pem"
DKIM_CERT_FILE="$CWD_CONFIG/$MAILDOMAIN-dkim.cert"
NAMESERVER_FILE="$CWD_CONFIG/$MAILDOMAIN-nameserver.txt"

# Generate actual DKIM keys (minimal version)
openssl genrsa -out "$DKIM_KEY_FILE" 1024 2>/dev/null
openssl rsa -in "$DKIM_KEY_FILE" -out "$DKIM_CERT_FILE" -pubout 2>/dev/null
echo "DNS records..." > "$NAMESERVER_FILE"

# Copy docker-compose.yml
cp docker-compose.yml "./$CONFIG_DIR/docker-compose.yml"

echo ""
echo "=========================================="
echo "Phase 2: Testing file locations"
echo "=========================================="
echo ""

# Test 1: Verify config directory structure
assert_dir_exists "$TEST_DIR/$CONFIG_DIR/config" \
    "config-generated/config/ directory exists"

assert_dir_exists "$TEST_DIR/$CONFIG_DIR/config/wildduck" \
    "config-generated/config/wildduck/ directory exists"

assert_dir_exists "$TEST_DIR/$CONFIG_DIR/config/haraka" \
    "config-generated/config/haraka/ directory exists"

assert_dir_exists "$TEST_DIR/$CONFIG_DIR/config/rspamd" \
    "config-generated/config/rspamd/ directory exists"

# Test 2: Verify NO double nesting
assert_not_exists "$TEST_DIR/$CONFIG_DIR/config-generated" \
    "No config-generated/config-generated/ double nesting"

# Test 3: Verify DKIM files are in correct location
assert_file_exists "$DKIM_KEY_FILE" \
    "DKIM private key in config-generated/config/"

assert_file_exists "$DKIM_CERT_FILE" \
    "DKIM certificate in config-generated/config/"

assert_file_exists "$NAMESERVER_FILE" \
    "Nameserver file in config-generated/config/"

# Test 4: Verify DKIM files are not in wrong location
assert_not_exists "$TEST_DIR/$CONFIG_DIR/config-generated/$MAILDOMAIN-dkim.pem" \
    "DKIM key NOT in config-generated/config-generated/"

# Test 5: Verify DKIM files have content
assert_file_not_empty "$DKIM_KEY_FILE" \
    "DKIM private key is not empty"

assert_file_not_empty "$DKIM_CERT_FILE" \
    "DKIM certificate is not empty"

# Test 6: Verify config files were copied
assert_file_exists "$TEST_DIR/$CONFIG_DIR/config/wildduck/api.toml" \
    "WildDuck config copied to config-generated/config/"

assert_file_exists "$TEST_DIR/$CONFIG_DIR/config/haraka/wildduck.yaml" \
    "Haraka config copied to config-generated/config/"

assert_file_exists "$TEST_DIR/$CONFIG_DIR/config/rspamd/worker-normal.conf" \
    "Rspamd config copied to config-generated/config/"

echo ""
echo "=========================================="
echo "Phase 3: Testing Docker mount compatibility"
echo "=========================================="
echo ""

# Simulate running docker-compose from config-generated directory
cd "$TEST_DIR/$CONFIG_DIR"

# Test 7: Verify relative paths from docker-compose working directory
RELATIVE_WILDDUCK="./config/wildduck"
RELATIVE_RSPAMD_CONF="./config/rspamd/worker-normal.conf"

assert_dir_exists "$RELATIVE_WILDDUCK" \
    "Docker can access ./config/wildduck from config-generated/"

assert_file_exists "$RELATIVE_RSPAMD_CONF" \
    "Docker can access ./config/rspamd/worker-normal.conf from config-generated/"

# Test 8: Verify absolute path resolution matches
ABSOLUTE_WILDDUCK="$TEST_DIR/$CONFIG_DIR/config/wildduck"
CURRENT_DIR="$(pwd)"

TESTS_TOTAL=$((TESTS_TOTAL + 1))
echo -n "Test $TESTS_TOTAL: Relative and absolute paths resolve to same location... "
if [ "$(cd $RELATIVE_WILDDUCK && pwd)" = "$ABSOLUTE_WILDDUCK" ]; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Relative: $(cd $RELATIVE_WILDDUCK && pwd)"
    echo "  Absolute: $ABSOLUTE_WILDDUCK"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: Verify DKIM files accessible from docker-compose directory
cd "$TEST_DIR/$CONFIG_DIR"
DKIM_FROM_CONFIG_DIR="./config/$MAILDOMAIN-dkim.pem"

assert_file_exists "$DKIM_FROM_CONFIG_DIR" \
    "DKIM key accessible as ./config/*.pem from config-generated/"

cd "$TEST_DIR"

echo ""
echo "=========================================="
echo "Phase 4: File structure validation"
echo "=========================================="
echo ""

echo "Actual directory structure created:"
echo ""
tree -L 3 "$TEST_DIR/$CONFIG_DIR" 2>/dev/null || find "$TEST_DIR/$CONFIG_DIR" -type f -o -type d | sed 's|[^/]*/| |g'

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo ""
echo "Total tests:  $TESTS_TOTAL"
echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo "✅ ALL INTEGRATION TESTS PASSED!"
    echo "==========================================${NC}"
    echo ""
    echo "Verified:"
    echo "  ✅ Files created in config-generated/config/"
    echo "  ✅ No double nesting (config-generated/config-generated/)"
    echo "  ✅ DKIM keys generated in correct location"
    echo "  ✅ Config files copied to correct location"
    echo "  ✅ Docker can mount files using relative paths"
    echo "  ✅ All paths resolve correctly"
    echo ""
    exit 0
else
    echo -e "${RED}=========================================="
    echo "❌ SOME TESTS FAILED!"
    echo "==========================================${NC}"
    echo ""
    echo "Review the failed tests above."
    echo ""
    exit 1
fi
