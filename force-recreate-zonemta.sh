#!/bin/bash

# Force recreate ZoneMTA and WildDuck containers to clear any cached connections

set -e

echo "=== Force Recreate ZoneMTA and WildDuck ==="
echo ""
echo "This will:"
echo "  1. Stop and remove ZoneMTA and WildDuck containers"
echo "  2. Recreate them with fresh configurations"
echo "  3. Clear any cached MongoDB connections"
echo ""

cd ./config-generated/

echo "Step 1: Checking current containers"
echo "------------------------------------"
sudo docker compose ps

echo ""
echo "Step 2: Stopping and removing containers"
echo "-----------------------------------------"
echo "Stopping ZoneMTA and WildDuck..."
sudo docker compose stop zonemta wildduck

echo "Removing containers..."
sudo docker compose rm -f zonemta wildduck

echo ""
echo "Step 3: Recreating containers"
echo "------------------------------"
echo "Starting WildDuck..."
sudo docker compose up -d wildduck

echo "Waiting for WildDuck to be ready..."
sleep 5

echo "Starting ZoneMTA..."
sudo docker compose up -d zonemta

echo "Waiting for ZoneMTA to start..."
sleep 5

echo ""
echo "Step 4: Verifying containers are running"
echo "-----------------------------------------"
sudo docker compose ps zonemta wildduck

echo ""
echo "Step 5: Checking ZoneMTA logs for database config"
echo "--------------------------------------------------"
echo "Looking for database connection info..."
sudo docker compose logs zonemta | grep -i "mongo\|database\|connection" | tail -10

echo ""
echo "Step 6: Full ZoneMTA logs (last 30 lines)"
echo "------------------------------------------"
sudo docker compose logs --tail=30 zonemta

cd ../

echo ""
echo "=== Containers Recreated Successfully ==="
echo ""
echo "Please try sending an email again."
echo ""
echo "If you still get the error, run this to see real-time logs:"
echo "  cd config-generated && sudo docker compose logs -f zonemta"
