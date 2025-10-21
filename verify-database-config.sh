#!/bin/bash

# Verification script to ensure ZoneMTA and WildDuck database configurations are correct
# This script checks that all database references use the same database name

set -e

echo "=== Database Configuration Verification ==="
echo ""

# Check if config files exist
if [ ! -d "./config-generated/config" ]; then
    echo "Error: config-generated/config directory not found"
    echo "Please run setup.sh first"
    exit 1
fi

# Get MongoDB URL from .env
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    exit 1
fi

source .env

MONGO_URL=${WILDDUCK_MONGO_URL:-mongodb://mongo:27017/wildduck}
DB_NAME=$(echo "$MONGO_URL" | sed 's/.*\///' | sed 's/?.*//' | sed 's/\/$//')

echo "Expected Configuration:"
echo "  MongoDB URL: $MONGO_URL"
echo "  Database Name: $DB_NAME"
echo ""

# Validation
if [ -z "$DB_NAME" ]; then
    echo "✗ ERROR: Could not extract database name from MongoDB URL"
    exit 1
fi

echo "Checking configuration files..."
echo ""

# Track if there are any issues
ISSUES_FOUND=0

# Check ZoneMTA database configuration files
echo "1. ZoneMTA Database Configuration Files"
echo "   ======================================="

for DBS_FILE in ./config-generated/config/zone-mta/dbs-*.toml; do
    if [ -f "$DBS_FILE" ]; then
        FILENAME=$(basename "$DBS_FILE")
        echo ""
        echo "   Checking $FILENAME..."

        # Extract mongo URL and sender from the file
        ACTUAL_MONGO=$(grep "^mongo =" "$DBS_FILE" | cut -d'"' -f2)
        ACTUAL_SENDER=$(grep "^sender =" "$DBS_FILE" | cut -d'"' -f2)

        echo "     mongo URL: $ACTUAL_MONGO"
        echo "     sender DB: $ACTUAL_SENDER"

        # Verify mongo URL matches
        if [ "$ACTUAL_MONGO" != "$MONGO_URL" ]; then
            echo "     ✗ WRONG mongo URL (expected: $MONGO_URL)"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo "     ✓ mongo URL correct"
        fi

        # Verify sender matches DB_NAME
        if [ "$ACTUAL_SENDER" != "$DB_NAME" ]; then
            echo "     ✗ WRONG sender database (expected: $DB_NAME)"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo "     ✓ sender database correct"
        fi
    fi
done

# Check WildDuck database configuration
echo ""
echo "2. WildDuck Database Configuration"
echo "   ================================"
echo ""

WILDDUCK_DBS="./config-generated/config/wildduck/dbs.toml"

if [ -f "$WILDDUCK_DBS" ]; then
    echo "   Checking dbs.toml..."

    ACTUAL_MONGO=$(grep "^mongo =" "$WILDDUCK_DBS" | cut -d'"' -f2)
    ACTUAL_SENDER=$(grep "^sender =" "$WILDDUCK_DBS" | cut -d'"' -f2)

    echo "     mongo URL: $ACTUAL_MONGO"
    echo "     sender DB: $ACTUAL_SENDER"

    if [ "$ACTUAL_MONGO" != "$MONGO_URL" ]; then
        echo "     ✗ WRONG mongo URL (expected: $MONGO_URL)"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo "     ✓ mongo URL correct"
    fi

    if [ "$ACTUAL_SENDER" != "$DB_NAME" ]; then
        echo "     ✗ WRONG sender database (expected: $DB_NAME)"
        echo "     ⚠️  This is the ROOT CAUSE of 'not authorized on zone-mta' errors!"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo "     ✓ sender database correct"
    fi
else
    echo "   ✗ dbs.toml not found"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check docker-compose.yml for NODE_ENV
echo ""
echo "3. Docker Compose Configuration"
echo "   ============================="
echo ""

DOCKER_COMPOSE="./config-generated/docker-compose.yml"

if [ -f "$DOCKER_COMPOSE" ]; then
    echo "   Checking docker-compose.yml for NODE_ENV..."

    if grep -A 10 "zonemta:" "$DOCKER_COMPOSE" | grep -q "NODE_ENV=production"; then
        echo "     ✓ ZoneMTA has NODE_ENV=production set"
    else
        echo "     ✗ ZoneMTA missing NODE_ENV=production"
        echo "     ⚠️  ZoneMTA may use dbs-development.toml instead of dbs-production.toml"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo "   ✗ docker-compose.yml not found"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Summary
echo ""
echo "=== Verification Summary ==="
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✓ All checks passed!"
    echo ""
    echo "Database configuration is correct:"
    echo "  - All ZoneMTA config files use: $DB_NAME"
    echo "  - WildDuck config uses: $DB_NAME"
    echo "  - NODE_ENV is set to production"
    echo ""
    echo "You should not see 'not authorized on zone-mta' errors."
    exit 0
else
    echo "✗ Found $ISSUES_FOUND issue(s)"
    echo ""
    echo "Please run one of the following to fix:"
    echo "  ./diagnose-and-fix-zonemta.sh"
    echo "  ./fix-zonemta-db.sh"
    echo ""
    exit 1
fi
