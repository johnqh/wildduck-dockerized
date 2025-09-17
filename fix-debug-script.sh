#!/bin/bash

echo "🔧 Fixing database debug script for container environment"
echo "========================================================"

# Check if we're running this on the server
if [ "$USER" = "root" ] && [ -f "/etc/hostname" ]; then
    echo "✅ Detected server environment"
else
    echo "ℹ️  Run this on the server: root@srv858831"
    exit 1
fi

echo ""
echo "1. Checking Docker and container status..."
docker-compose ps

echo ""
echo "2. Checking if WildDuck container has Node.js dependencies..."
if docker-compose exec -T wildduck which node >/dev/null 2>&1; then
    echo "✅ Node.js is available in WildDuck container"
    
    echo ""
    echo "3. Checking if MongoDB package is available..."
    if docker-compose exec -T wildduck node -e "require('mongodb')" >/dev/null 2>&1; then
        echo "✅ MongoDB package is available"
    else
        echo "❌ MongoDB package not found in container"
        echo "   The container might not have the mongodb package installed"
    fi
    
    echo ""
    echo "4. Checking if Redis package is available..."
    if docker-compose exec -T wildduck node -e "require('ioredis')" >/dev/null 2>&1; then
        echo "✅ Redis package is available"
    else
        echo "❌ Redis package not found in container"
        echo "   The container might not have the ioredis package installed"
    fi
    
else
    echo "❌ Node.js not found in WildDuck container"
fi

echo ""
echo "5. Testing basic connectivity..."
echo "   MongoDB connectivity:"
if docker-compose exec -T wildduck ping -c 1 mongo >/dev/null 2>&1; then
    echo "   ✅ Can reach mongo container"
else
    echo "   ❌ Cannot reach mongo container"
fi

echo "   Redis connectivity:"
if docker-compose exec -T wildduck ping -c 1 redis >/dev/null 2>&1; then
    echo "   ✅ Can reach redis container"
else
    echo "   ❌ Cannot reach redis container"
fi

echo ""
echo "6. Checking MongoDB with mongosh..."
if docker-compose exec -T mongo mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "   ✅ MongoDB is responding to ping"
else
    echo "   ❌ MongoDB is not responding"
fi

echo ""
echo "7. Checking Redis..."
if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
    echo "   ✅ Redis is responding to ping"
else
    echo "   ❌ Redis is not responding"
fi

echo ""
echo "8. Copying debug script to WildDuck container and testing..."
if docker-compose cp debug-db-connection.js wildduck:/tmp/debug-db-connection.js; then
    echo "   ✅ Debug script copied to container"
    echo "   Running test inside container..."
    docker-compose exec -T wildduck node /tmp/debug-db-connection.js
else
    echo "   ❌ Failed to copy debug script to container"
fi

echo ""
echo "🔍 Diagnosis complete. Check the results above."