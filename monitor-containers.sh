#!/bin/bash

echo "🔍 WildDuck Container Monitor"
echo "============================"
echo "Monitoring container health and logs..."
echo ""

# Function to check container status
check_container_status() {
    local container_name=$1
    local status=$(docker-compose ps -q $container_name 2>/dev/null | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null)
    local health=$(docker-compose ps -q $container_name 2>/dev/null | xargs docker inspect --format='{{.State.Health.Status}}' 2>/dev/null)
    
    if [ -z "$status" ]; then
        echo "❌ $container_name: NOT FOUND"
    else
        local health_indicator=""
        case "$health" in
            "healthy") health_indicator="🟢" ;;
            "unhealthy") health_indicator="🔴" ;;
            "starting") health_indicator="🟡" ;;
            *) health_indicator="⚪" ;;
        esac
        
        echo "$health_indicator $container_name: $status $([ "$health" != "null" ] && echo "($health)")"
    fi
}

# Function to show recent logs
show_recent_logs() {
    local container_name=$1
    local lines=${2:-10}
    
    echo ""
    echo "📋 Recent logs for $container_name (last $lines lines):"
    echo "----------------------------------------"
    docker-compose logs --tail=$lines $container_name 2>/dev/null || echo "❌ Failed to get logs for $container_name"
    echo ""
}

# Function to monitor in real-time
monitor_realtime() {
    echo "🔄 Starting real-time monitoring (Ctrl+C to stop)..."
    echo ""
    
    while true; do
        clear
        echo "🔍 WildDuck Container Monitor - $(date)"
        echo "========================================"
        echo ""
        
        echo "📊 Container Status:"
        echo "-------------------"
        check_container_status "mongo"
        check_container_status "redis"
        check_container_status "wildduck"
        check_container_status "traefik"
        
        echo ""
        echo "🔄 WildDuck Container Restarts in last 5 minutes:"
        echo "------------------------------------------------"
        local restart_count=$(docker events --since='5m' --filter container=$(docker-compose ps -q wildduck 2>/dev/null) --filter event=restart 2>/dev/null | wc -l)
        echo "Restart count: $restart_count"
        
        if [ "$restart_count" -gt 0 ]; then
            echo ""
            echo "⚠️  Recent WildDuck events:"
            docker events --since='5m' --filter container=$(docker-compose ps -q wildduck 2>/dev/null) 2>/dev/null | tail -5
        fi
        
        echo ""
        echo "📝 Latest WildDuck logs:"
        echo "----------------------"
        docker-compose logs --tail=5 wildduck 2>/dev/null | sed 's/^/  /'
        
        echo ""
        echo "Next update in 10 seconds... (Ctrl+C to stop)"
        sleep 10
    done
}

# Function to run database connectivity test
test_database_connectivity() {
    echo "🧪 Testing database connectivity..."
    echo ""
    
    if [ -f "./debug-db-connection.js" ]; then
        echo "Copying debug script to container..."
        if docker-compose cp debug-db-connection.js wildduck:/tmp/debug-db-connection.js 2>/dev/null; then
            echo "Running database connection test inside container..."
            docker-compose exec -T wildduck node /tmp/debug-db-connection.js 2>/dev/null || {
                echo "❌ Database test failed inside container"
                echo ""
                echo "🔍 Basic connectivity checks:"
                echo "MongoDB ping:"
                if docker-compose exec -T mongo mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
                    echo "  ✅ MongoDB is responding"
                else
                    echo "  ❌ MongoDB is not responding"
                fi
                
                echo "Redis ping:"
                if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
                    echo "  ✅ Redis is responding"
                else
                    echo "  ❌ Redis is not responding"
                fi
                
                echo "Network connectivity from WildDuck:"
                if docker-compose exec -T wildduck ping -c 1 mongo >/dev/null 2>&1; then
                    echo "  ✅ Can reach mongo"
                else
                    echo "  ❌ Cannot reach mongo"
                fi
                
                if docker-compose exec -T wildduck ping -c 1 redis >/dev/null 2>&1; then
                    echo "  ✅ Can reach redis"
                else
                    echo "  ❌ Cannot reach redis"
                fi
            }
        else
            echo "❌ Failed to copy debug script to container"
            echo "Falling back to basic connectivity tests..."
            
            echo ""
            echo "🔍 Basic connectivity checks:"
            echo "Container status:"
            docker-compose ps 2>/dev/null || echo "  ❌ Docker Compose not available"
            
            echo "MongoDB connectivity:"
            if docker-compose exec -T mongo mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
                echo "  ✅ MongoDB is responding"
            else
                echo "  ❌ MongoDB is not responding"
            fi
            
            echo "Redis connectivity:"
            if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
                echo "  ✅ Redis is responding"
            else
                echo "  ❌ Redis is not responding"
            fi
        fi
    else
        echo "❌ debug-db-connection.js not found"
    fi
}

# Main menu
case "${1:-status}" in
    "status")
        echo "📊 Current Container Status:"
        echo "----------------------------"
        check_container_status "mongo"
        check_container_status "redis"
        check_container_status "wildduck"
        check_container_status "traefik"
        ;;
        
    "logs")
        echo "📋 Container Logs:"
        echo "------------------"
        show_recent_logs "wildduck" 20
        show_recent_logs "mongo" 10
        show_recent_logs "redis" 10
        ;;
        
    "monitor")
        monitor_realtime
        ;;
        
    "test")
        test_database_connectivity
        ;;
        
    "full")
        echo "📊 Container Status:"
        echo "-------------------"
        check_container_status "mongo"
        check_container_status "redis"
        check_container_status "wildduck"
        check_container_status "traefik"
        
        echo ""
        show_recent_logs "wildduck" 15
        
        echo "🧪 Testing database connectivity..."
        test_database_connectivity
        ;;
        
    *)
        echo "Usage: $0 [status|logs|monitor|test|full]"
        echo ""
        echo "Commands:"
        echo "  status  - Show current container status (default)"
        echo "  logs    - Show recent container logs"
        echo "  monitor - Real-time monitoring (Ctrl+C to stop)"
        echo "  test    - Test database connectivity"
        echo "  full    - Full diagnostic report"
        echo ""
        exit 1
        ;;
esac