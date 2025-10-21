#!/bin/bash

# Debug Haraka configuration to see what's actually in the container

echo "=== Haraka Configuration Debug ==="
echo ""

cd ./config-generated/ || exit 1

echo "1. Checking connection.ini on HOST:"
echo "   ================================"
if [ -f "config/haraka/connection.ini" ]; then
    cat config/haraka/connection.ini
else
    echo "✗ File not found: config/haraka/connection.ini"
fi

echo ""
echo "2. Checking connection.ini INSIDE container:"
echo "   =========================================="
sudo docker compose exec haraka cat /app/config/connection.ini 2>/dev/null || echo "✗ File not found in container"

echo ""
echo "3. Listing all config files in container:"
echo "   ======================================="
sudo docker compose exec haraka ls -la /app/config/ 2>/dev/null || echo "✗ Cannot list container files"

echo ""
echo "4. Checking Haraka config loading path:"
echo "   ======================================"
sudo docker compose exec haraka node -e "
const config = require('haraka-config');
console.log('Config directory:', config.get_config_dir());
try {
    const conn = config.get('connection.ini');
    console.log('Connection config:', JSON.stringify(conn, null, 2));
} catch (e) {
    console.log('Error loading connection.ini:', e.message);
}
" 2>/dev/null || echo "✗ Cannot check config"

echo ""
echo "5. Checking if config is object or path issue:"
echo "   ==========================================="
sudo docker compose exec haraka node -e "
const config = require('haraka-config');
const conn = config.get('connection.ini', 'ini');
console.log('Full connection config:');
console.log(JSON.stringify(conn, null, 2));
if (conn && conn.main && conn.main.greeting) {
    console.log('✓ greeting found:', conn.main.greeting);
} else {
    console.log('✗ greeting NOT found in config');
    console.log('Config keys:', Object.keys(conn || {}));
}
" 2>/dev/null || echo "✗ Cannot inspect config object"

echo ""
echo "=== Debug Complete ==="
