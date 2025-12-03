# WildDuck Database Connection Debugging Guide

This guide helps debug database connection issues that can cause WildDuck containers to restart every 60 seconds.

## 🔍 Quick Diagnosis

### 1. Check Container Status

```bash
./monitor-containers.sh status
```

### 2. Monitor Real-time

```bash
./monitor-containers.sh monitor
```

### 3. Test Database Connectivity

```bash
./monitor-containers.sh test
```

### 4. Full Diagnostic Report

```bash
./monitor-containers.sh full
```

## 🛠 Enhanced Logging Features

### WildDuck Source Code Improvements (`../wildduck`)

1. **Enhanced Database Connection Logging** (`lib/db.js`):
   - Added detailed MongoDB connection attempts with masked credentials
   - Added Redis connection event handlers
   - Added connection timeout options (10s server selection, 10s connect)
   - Added connection retry strategy logging

2. **Worker Process Retry Logic** (`worker.js`):
   - Added exponential backoff retry mechanism (max 5 attempts)
   - Enhanced error logging with error codes and stack traces
   - Added attempt counters and retry delay information
   - Added process startup logging with PID tracking

### Docker Configuration Improvements

1. **Health Checks** (`docker-compose.yml`):
   - Added MongoDB health check with `mongosh ping`
   - Added Redis health check with `redis-cli ping`
   - Added WildDuck health check using `/health` endpoint
   - Added proper service dependencies with health conditions

2. **Connection String Optimization** (`default-config/wildduck/dbs.toml`):
   - Added MongoDB connection timeout parameters
   - Optimized connection pool settings
   - Added socket timeout configuration

## 📊 Log Analysis

### MongoDB Connection Logs

Look for these log patterns:

```text
DB: Attempting to connect to MongoDB: mongodb://***:***@mongo:27017/wildduck
DB: Successfully connected to MongoDB: mongodb://***:***@mongo:27017/wildduck
DB: Failed to connect to MongoDB: mongodb://***:***@mongo:27017/wildduck. Error: [error message]
```

### Redis Connection Logs

Look for these log patterns:

```text
Redis: Attempting to connect to Redis: redis:6379 (db:3)
Redis: Successfully connected to Redis: redis:6379 (db:3)
Redis: Redis connection error: [error message]
Redis: Connection retry times=1 delay=1000
```

### Worker Process Logs

Look for these log patterns:

```text
App: Starting WildDuck worker process. PID=123
App: Initializing database connections... (attempt 1/6)
Db: Database connections established successfully on attempt 1
Db: Retrying database connection in 2000ms... (attempt 2/6)
```

## 🚨 Common Issues and Solutions

### Issue 1: MongoDB Connection Timeout

**Symptoms:**

```text
DB: Failed to connect to MongoDB: mongodb://***:***@mongo:27017/wildduck. Error: Server selection timed out after 10000 ms
```

**Solutions:**

1. Check MongoDB container health: `docker-compose ps mongo`
2. Verify MongoDB is accepting connections: `docker-compose exec mongo mongosh --eval "db.adminCommand('ping')"`
3. Check network connectivity: `docker-compose exec wildduck ping mongo`

### Issue 2: Redis Connection Failure

**Symptoms:**

```text
Redis: Redis connection error: connect ECONNREFUSED redis:6379
```

**Solutions:**

1. Check Redis container health: `docker-compose ps redis`
2. Verify Redis is accepting connections: `docker-compose exec redis redis-cli ping`
3. Check network connectivity: `docker-compose exec wildduck ping redis`

### Issue 3: Container Restart Loop

**Symptoms:**

- WildDuck container restarts every 60 seconds
- Exit code 1 in container logs

**Solutions:**

1. Check if databases are ready before WildDuck starts:

   ```bash
   ./wait-for-services.sh
   ```

2. Review worker process logs for connection failures
3. Verify health check endpoints are responding

## 🔧 Debugging Tools

### 1. Database Connection Test Script

```bash
node debug-db-connection.js
```

This script tests:

- MongoDB connectivity and operations
- Redis connectivity and operations
- Connection timing and error details

### 2. Container Monitoring Script

```bash
./monitor-containers.sh [command]
```

Commands:

- `status` - Show current container status
- `logs` - Show recent container logs
- `monitor` - Real-time monitoring
- `test` - Test database connectivity
- `full` - Full diagnostic report

### 3. Service Dependency Checker

```bash
./wait-for-services.sh
```

This script:

- Tests network connectivity to services
- Waits for MongoDB to be ready
- Waits for Redis to be ready
- Can be used as a startup dependency

## 📈 Performance Monitoring

### Connection Pool Settings

The optimized MongoDB connection includes:

- `serverSelectionTimeoutMS=10000` - 10 second server selection timeout
- `connectTimeoutMS=10000` - 10 second connection timeout
- `socketTimeoutMS=0` - Disabled socket timeout
- `maxPoolSize=10` - Maximum 10 connections
- `minPoolSize=1` - Minimum 1 connection
- `maxIdleTimeMS=30000` - Close idle connections after 30s

### Retry Strategy

The worker process retry logic includes:

- Exponential backoff: 1s, 2s, 4s, 8s, 10s (max)
- Maximum 5 retry attempts
- Detailed logging for each attempt
- Graceful shutdown after max retries

## 🔍 Advanced Debugging

### Enable Verbose Logging

The log level is already set to `silly` in `default-config/wildduck/default.toml`:

```toml
[log]
level = "silly"
```

### Docker Network Inspection

```bash
# List Docker networks
docker network ls

# Inspect the default network
docker network inspect wildduck-dockerized_default

# Check container network connectivity
docker-compose exec wildduck nslookup mongo
docker-compose exec wildduck nslookup redis
```

### Container Resource Usage

```bash
# Check container resource usage
docker-compose exec wildduck top

# Check container memory usage
docker-compose exec wildduck cat /proc/meminfo

# Check container disk usage
docker-compose exec wildduck df -h
```

## 📋 Troubleshooting Checklist

- [ ] All containers are running and healthy
- [ ] MongoDB accepts connections and responds to ping
- [ ] Redis accepts connections and responds to ping
- [ ] Network connectivity between containers works
- [ ] WildDuck configuration files are properly mounted
- [ ] Database connection strings use correct hostnames
- [ ] No firewall or security group blocking connections
- [ ] Sufficient system resources (CPU, memory, disk)
- [ ] Docker daemon is running and responsive
- [ ] No conflicting services on required ports

## 📞 Getting Help

If issues persist after following this guide:

1. Collect diagnostic information:

   ```bash
   ./monitor-containers.sh full > diagnostic-report.txt 2>&1
   ```

2. Check recent commits for any configuration changes
3. Verify the Docker image version and compatibility
4. Review system logs for underlying infrastructure issues

Remember: The enhanced logging will now provide much more detailed information about exactly where and why database connections are failing, making it easier to identify and resolve issues quickly.
