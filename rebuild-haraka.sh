#!/bin/bash

# Fully rebuild Haraka container to clear any cached config
# This ensures the new connection.ini is loaded properly

echo "=== Rebuild Haraka Container ==="
echo ""

cd ./config-generated/ || exit 1

echo "Step 1: Stopping and removing Haraka container..."
sudo docker compose stop haraka
sudo docker compose rm -f haraka

echo ""
echo "Step 2: Verifying connection.ini has greeting..."
if grep -q "^greeting=" config/haraka/connection.ini; then
    echo "✓ connection.ini has greeting:"
    grep "^greeting=" config/haraka/connection.ini
else
    echo "✗ WARNING: connection.ini missing greeting!"
    echo "  Adding it now..."
    HOSTNAME=$(grep -E "EMAIL_DOMAIN" ../.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "0xmail.box")

    if grep -q "^\[main\]" config/haraka/connection.ini; then
        sed -i "/^\[main\]/a greeting=$HOSTNAME ESMTP Haraka" config/haraka/connection.ini
    else
        sed -i "1i [main]\ngreeting=$HOSTNAME ESMTP Haraka\n" config/haraka/connection.ini
    fi
    echo "✓ Added greeting"
fi

echo ""
echo "Step 3: Recreating Haraka container (fresh start)..."
sudo docker compose up -d haraka

echo ""
echo "Step 4: Waiting for Haraka to start..."
sleep 5

echo ""
echo "Step 5: Checking container status..."
sudo docker compose ps haraka

echo ""
echo "Step 6: Checking logs..."
sudo docker compose logs --tail=30 haraka

echo ""
echo "=== Rebuild Complete ==="
echo ""
echo "Watch logs for incoming connections:"
echo "  sudo docker compose logs -f haraka"
echo ""
echo "If you still see the greeting error, run this to inspect the container:"
echo "  sudo docker compose exec haraka cat /app/config/connection.ini"
