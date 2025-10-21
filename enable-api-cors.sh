#!/bin/bash

# Enable CORS headers for WildDuck API via Traefik middleware

echo "=== Enable API CORS Headers ==="
echo ""

# Detect directory
if [ -f "docker-compose.yml" ] && [ -d "config" ]; then
    CONFIG_DIR="."
elif [ -d "config-generated" ]; then
    CONFIG_DIR="./config-generated"
else
    echo "Error: Cannot find config-generated directory"
    exit 1
fi

cd "$CONFIG_DIR"

echo "Restarting Traefik and WildDuck to apply CORS middleware..."
sudo docker compose restart traefik wildduck

echo ""
echo "Waiting for services to start..."
sleep 5

echo ""
echo "Checking Traefik logs for middleware:"
sudo docker compose logs --tail=20 traefik | grep -i "cors\|middleware" || echo "(No CORS logs yet)"

echo ""
echo "Checking WildDuck health:"
sudo docker compose exec wildduck wget -qO- http://127.0.0.1:8080/health || echo "Health check failed"

echo ""
echo "=== Done! ==="
echo ""
echo "CORS headers have been enabled for the WildDuck API."
echo "The API should now accept requests from localhost:5173 and other origins."
echo ""
echo "Test the API:"
echo "  curl -H 'Origin: http://localhost:5173' -I http://mail.0xmail.box/api/health"
echo ""
echo "Expected headers:"
echo "  Access-Control-Allow-Origin: *"
echo "  Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS"
