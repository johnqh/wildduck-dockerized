#!/bin/bash

echo "🩺 WildDuck Quick Diagnosis"
echo "=========================="
echo "Running basic health checks..."
echo ""

# Check if Docker Compose is available
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ docker-compose command not found"
    exit 1
fi

echo "1. 📊 Container Status:"
echo "---------------------"
docker-compose ps 2>/dev/null || {
    echo "❌ Failed to get container status"
    exit 1
}

echo ""
echo "2. 🔗 Network Connectivity:"
echo "---------------------------"

# Test MongoDB connectivity
echo "MongoDB (mongo:27017):"
if docker-compose exec -T wildduck ping -c 1 mongo >/dev/null 2>&1; then
    echo "  ✅ Network reachable"
    if docker-compose exec -T mongo mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        echo "  ✅ Service responding"
    else
        echo "  ❌ Service not responding"
    fi
else
    echo "  ❌ Network unreachable"
fi

# Test Redis connectivity
echo "Redis (redis:6379):"
if docker-compose exec -T wildduck ping -c 1 redis >/dev/null 2>&1; then
    echo "  ✅ Network reachable"
    if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
        echo "  ✅ Service responding"
    else
        echo "  ❌ Service not responding"
    fi
else
    echo "  ❌ Network unreachable"
fi

echo ""
echo "3. 📋 Recent WildDuck Logs:"
echo "--------------------------"
docker-compose logs --tail=10 wildduck 2>/dev/null | sed 's/^/  /'

echo ""
echo "4. 🔄 Container Restart Check:"
echo "-----------------------------"
# Check for recent restarts in last 5 minutes
restart_count=$(docker events --since='5m' --filter container=$(docker-compose ps -q wildduck 2>/dev/null) --filter event=restart 2>/dev/null | wc -l)
echo "WildDuck restarts in last 5 minutes: $restart_count"

if [ "$restart_count" -gt 0 ]; then
    echo ""
    echo "Recent restart events:"
    docker events --since='5m' --filter container=$(docker-compose ps -q wildduck 2>/dev/null) 2>/dev/null | tail -3 | sed 's/^/  /'
fi

echo ""
echo "5. 🔍 Health Check Status:"
echo "-------------------------"
wildduck_container=$(docker-compose ps -q wildduck 2>/dev/null)
if [ -n "$wildduck_container" ]; then
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$wildduck_container" 2>/dev/null)
    case "$health_status" in
        "healthy") echo "WildDuck health: 🟢 Healthy" ;;
        "unhealthy") echo "WildDuck health: 🔴 Unhealthy" ;;
        "starting") echo "WildDuck health: 🟡 Starting" ;;
        "null"|"") echo "WildDuck health: ⚪ No health check configured" ;;
        *) echo "WildDuck health: ❓ Unknown ($health_status)" ;;
    esac
else
    echo "WildDuck health: ❌ Container not found"
fi

echo ""
echo "6. 🧪 Basic Database Test:"
echo "-------------------------"
echo "Testing database services directly..."

# Test MongoDB
echo "MongoDB test:"
if docker-compose exec -T mongo mongosh --quiet --eval "
try {
    db.adminCommand('ping');
    print('✅ MongoDB ping successful');
    
    db.test.insertOne({test: true, timestamp: new Date()});
    print('✅ MongoDB write test successful');
    
    db.test.drop();
    print('✅ MongoDB cleanup successful');
} catch(e) {
    print('❌ MongoDB test failed: ' + e.message);
}
" 2>/dev/null; then
    true
else
    echo "❌ MongoDB test execution failed"
fi

# Test Redis
echo "Redis test:"
if docker-compose exec -T redis redis-cli eval "
redis.call('ping');
redis.call('set', 'test_key', 'test_value');
local val = redis.call('get', 'test_key');
redis.call('del', 'test_key');
return 'Redis test successful: ' .. val;
" 0 2>/dev/null | head -1; then
    echo "✅ Redis test successful"
else
    echo "❌ Redis test failed"
fi

echo ""
echo "📋 Quick Diagnosis Summary:"
echo "=========================="
echo "If you see ❌ errors above, those indicate the root cause of the 60s restart issue."
echo "Check the DATABASE-DEBUG.md file for detailed troubleshooting steps."
echo ""
echo "Common fixes:"
echo "- Restart containers: docker-compose restart"
echo "- Check Docker resources: docker system df"
echo "- Review full logs: docker-compose logs"