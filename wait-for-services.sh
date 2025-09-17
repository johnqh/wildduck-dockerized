#!/bin/bash

# Wait for MongoDB and Redis to be ready before starting WildDuck
# This script can be used as an init container or startup dependency

set -e

echo "🔄 Waiting for required services to be ready..."

# Function to wait for MongoDB
wait_for_mongo() {
    local host=${1:-mongo}
    local port=${2:-27017}
    local timeout=${3:-60}
    
    echo "⏳ Waiting for MongoDB at $host:$port..."
    
    local count=0
    until mongosh --host "$host:$port" --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
        count=$((count + 1))
        if [ $count -gt $timeout ]; then
            echo "❌ Timeout waiting for MongoDB after ${timeout} seconds"
            return 1
        fi
        echo "   MongoDB not ready yet (attempt $count/$timeout)..."
        sleep 1
    done
    
    echo "✅ MongoDB is ready!"
    return 0
}

# Function to wait for Redis
wait_for_redis() {
    local host=${1:-redis}
    local port=${2:-6379}
    local timeout=${3:-60}
    
    echo "⏳ Waiting for Redis at $host:$port..."
    
    local count=0
    until redis-cli -h "$host" -p "$port" ping >/dev/null 2>&1; do
        count=$((count + 1))
        if [ $count -gt $timeout ]; then
            echo "❌ Timeout waiting for Redis after ${timeout} seconds"
            return 1
        fi
        echo "   Redis not ready yet (attempt $count/$timeout)..."
        sleep 1
    done
    
    echo "✅ Redis is ready!"
    return 0
}

# Function to test network connectivity
test_network_connectivity() {
    local host=$1
    local port=$2
    
    echo "🔍 Testing network connectivity to $host:$port..."
    
    if nc -z "$host" "$port" 2>/dev/null; then
        echo "✅ Network connectivity to $host:$port is working"
        return 0
    else
        echo "❌ Cannot reach $host:$port"
        return 1
    fi
}

# Main execution
main() {
    local mongo_host=${MONGO_HOST:-mongo}
    local mongo_port=${MONGO_PORT:-27017}
    local redis_host=${REDIS_HOST:-redis}
    local redis_port=${REDIS_PORT:-6379}
    local timeout=${WAIT_TIMEOUT:-60}
    
    echo "🚀 Service dependency checker"
    echo "=============================="
    echo "MongoDB: $mongo_host:$mongo_port"
    echo "Redis: $redis_host:$redis_port"
    echo "Timeout: ${timeout}s"
    echo ""
    
    # Test basic network connectivity first
    if ! test_network_connectivity "$mongo_host" "$mongo_port"; then
        echo "❌ Basic network connectivity to MongoDB failed"
        exit 1
    fi
    
    if ! test_network_connectivity "$redis_host" "$redis_port"; then
        echo "❌ Basic network connectivity to Redis failed"
        exit 1
    fi
    
    # Wait for services to be ready
    if ! wait_for_mongo "$mongo_host" "$mongo_port" "$timeout"; then
        echo "❌ MongoDB readiness check failed"
        exit 1
    fi
    
    if ! wait_for_redis "$redis_host" "$redis_port" "$timeout"; then
        echo "❌ Redis readiness check failed"
        exit 1
    fi
    
    echo ""
    echo "🎉 All services are ready! Starting WildDuck..."
    echo ""
    
    # If arguments are provided, execute them as the main command
    if [ $# -gt 0 ]; then
        exec "$@"
    fi
}

# Run the main function with all arguments
main "$@"