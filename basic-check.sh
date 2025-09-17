#!/bin/bash

echo "🔍 Basic Docker Environment Check"
echo "================================="
echo ""

# Check Docker availability
echo "1. Docker Installation:"
echo "----------------------"
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker is installed"
    docker version --format '{{.Server.Version}}' 2>/dev/null && echo "✅ Docker daemon is running" || echo "❌ Docker daemon is not running"
else
    echo "❌ Docker is not installed"
    exit 1
fi

echo ""

# Check Docker Compose availability
echo "2. Docker Compose:"
echo "------------------"
if command -v docker-compose >/dev/null 2>&1; then
    echo "✅ docker-compose (legacy) is available"
    docker-compose version --short 2>/dev/null
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "✅ docker compose (modern) is available"
    docker compose version --short 2>/dev/null
else
    echo "❌ No Docker Compose found"
    echo "Please install docker-compose or upgrade Docker to include 'docker compose'"
    exit 1
fi

echo ""

# Detect which compose command to use
DOCKER_COMPOSE=""
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
fi

echo "3. Project Status:"
echo "------------------"
if [ -f "docker-compose.yml" ]; then
    echo "✅ docker-compose.yml found"
else
    echo "❌ docker-compose.yml not found"
    echo "Are you in the correct directory?"
    exit 1
fi

echo ""

# Try to get container status
echo "4. Container Status:"
echo "-------------------"
if $DOCKER_COMPOSE ps >/dev/null 2>&1; then
    echo "✅ Docker Compose is working"
    $DOCKER_COMPOSE ps
else
    echo "❌ Docker Compose failed"
    echo "Try running: $DOCKER_COMPOSE up -d"
fi

echo ""

echo "5. Quick Commands:"
echo "------------------"
echo "Start containers:    $DOCKER_COMPOSE up -d"
echo "View logs:          $DOCKER_COMPOSE logs -f wildduck"
echo "Restart WildDuck:   $DOCKER_COMPOSE restart wildduck"
echo "Full restart:       $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d"
echo "Check status:       $DOCKER_COMPOSE ps"

echo ""

# Check if containers are running and provide specific advice
container_count=$($DOCKER_COMPOSE ps -q 2>/dev/null | wc -l)
if [ "$container_count" -eq 0 ]; then
    echo "⚠️  No containers are running!"
    echo "Start them with: $DOCKER_COMPOSE up -d"
elif [ "$container_count" -lt 4 ]; then
    echo "⚠️  Only $container_count containers running (expected: 4+)"
    echo "Some services may be failing to start"
else
    echo "✅ $container_count containers are running"
fi