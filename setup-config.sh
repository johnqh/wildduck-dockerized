#!/bin/bash

echo "🔧 Setting Up WildDuck Configuration Files"
echo "=========================================="
echo ""

echo "1. Checking current configuration status:"
echo "----------------------------------------"
if [ -d "config" ]; then
    echo "✅ config/ directory exists"
    ls -la config/ | head -10
else
    echo "❌ config/ directory missing"
    echo "Creating config/ directory..."
    mkdir -p config
fi

echo ""
echo "2. Checking for default configuration templates:"
echo "----------------------------------------------"
if [ -d "default-config" ]; then
    echo "✅ default-config/ directory found"
    ls -la default-config/
else
    echo "❌ default-config/ directory missing"
    echo "This should not happen - checking git status..."
    git status
    exit 1
fi

echo ""
echo "3. Copying configuration files:"
echo "------------------------------"
echo "Copying default-config/* to config/..."

# Copy all default configuration files
cp -r default-config/* config/ 2>/dev/null || {
    echo "❌ Failed to copy configuration files"
    echo "Trying with explicit directory creation..."
    
    mkdir -p config/wildduck
    mkdir -p config/wildduck-webmail
    mkdir -p config/zone-mta
    mkdir -p config/haraka
    mkdir -p config/rspamd
    
    cp -r default-config/wildduck/* config/wildduck/ 2>/dev/null
    cp -r default-config/wildduck-webmail/* config/wildduck-webmail/ 2>/dev/null || echo "wildduck-webmail config not found"
    cp -r default-config/zone-mta/* config/zone-mta/ 2>/dev/null || echo "zone-mta config not found"
    cp -r default-config/haraka/* config/haraka/ 2>/dev/null || echo "haraka config not found"
    cp -r default-config/rspamd/* config/rspamd/ 2>/dev/null || echo "rspamd config not found"
}

echo ""
echo "4. Verifying configuration files:"
echo "--------------------------------"
echo "WildDuck configuration files:"
if [ -f "config/wildduck/default.toml" ]; then
    echo "  ✅ config/wildduck/default.toml"
else
    echo "  ❌ config/wildduck/default.toml missing"
fi

if [ -f "config/wildduck/dbs.toml" ]; then
    echo "  ✅ config/wildduck/dbs.toml"
else
    echo "  ❌ config/wildduck/dbs.toml missing"
fi

if [ -f "config/wildduck/api.toml" ]; then
    echo "  ✅ config/wildduck/api.toml"
else
    echo "  ❌ config/wildduck/api.toml missing"
fi

echo ""
echo "5. Configuration file permissions:"
echo "--------------------------------"
chmod -R 644 config/
find config/ -type d -exec chmod 755 {} \;
echo "✅ Set proper permissions on configuration files"

echo ""
echo "6. Quick test commands:"
echo "---------------------"
echo "Restart WildDuck container:"
echo "  docker compose -f docker-compose-no-ports.yml restart wildduck"
echo ""
echo "Monitor logs:"
echo "  docker compose -f docker-compose-no-ports.yml logs -f wildduck"
echo ""
echo "Check container status:"
echo "  docker compose -f docker-compose-no-ports.yml ps"

echo ""
echo "✅ Configuration setup complete!"
echo ""
echo "Expected result: WildDuck should now start successfully and show"
echo "database connection logs instead of file not found errors."