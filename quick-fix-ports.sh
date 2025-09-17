#!/bin/bash

echo "🔧 Quick Fix: Remove Port Bindings for Testing"
echo "============================================="
echo ""

echo "1. Checking current port usage:"
echo "------------------------------"
echo "Port 80:"
netstat -tlnp | grep :80 || echo "  No process on port 80"
echo "Port 8080:"
netstat -tlnp | grep :8080 || echo "  No process on port 8080"

echo ""
echo "2. Docker containers using ports:"
echo "--------------------------------"
docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null || echo "No running containers"

echo ""
echo "3. Creating docker-compose-no-ports.yml for testing:"
echo "---------------------------------------------------"

# Create a version without port bindings for testing
cat > docker-compose-no-ports.yml << 'EOF'
version: "3.8"
volumes:
  mongo:
  redis:
services:
  wildduck:
    image: johnqh/wildduck:latest
    restart: unless-stopped
    # NO PORT BINDINGS - for internal testing only
    depends_on:
      mongo:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./config/wildduck:/wildduck/config
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  mongo:
    image: mongo
    restart: unless-stopped
    volumes:
      - mongo:/data/db
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  redis:
    image: redis:alpine
    restart: unless-stopped
    volumes:
      - redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
EOF

echo "✅ Created docker-compose-no-ports.yml"
echo ""

echo "4. Testing commands:"
echo "------------------"
echo "Stop current containers:"
echo "  docker compose down"
echo ""
echo "Start with no port conflicts:"
echo "  docker compose -f docker-compose-no-ports.yml up -d"
echo ""
echo "Monitor logs for 60s restart issue:"
echo "  docker compose -f docker-compose-no-ports.yml logs -f wildduck"
echo ""
echo "Check container status:"
echo "  watch -n 5 'docker compose -f docker-compose-no-ports.yml ps'"
echo ""

echo "🎯 This will let us focus on the database connection issue"
echo "   without worrying about port conflicts!"