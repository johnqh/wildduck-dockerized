#!/bin/bash

# Fix CORS by checking current Traefik configuration

echo "=== Checking Traefik CORS Configuration ==="
echo ""

cd ./config-generated 2>/dev/null || cd .

echo "1. Check Traefik container labels:"
sudo docker inspect config-generated-wildduck-1 | grep -A 5 "cors" || echo "No CORS labels found"

echo ""
echo "2. Check Traefik dashboard/API for middleware:"
sudo docker compose exec traefik wget -qO- http://localhost:8080/api/http/middlewares 2>/dev/null | grep -i cors || echo "Traefik API not accessible or no CORS middleware"

echo ""
echo "3. Test API with CORS headers:"
curl -v -H "Origin: http://localhost:5173" http://mail.0xmail.box/api/health 2>&1 | grep -i "access-control\|< HTTP"

echo ""
echo "=== Done ==="
