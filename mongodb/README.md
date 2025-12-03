# MongoDB Configuration for WildDuck Mail Server

Complete MongoDB setup files for Windows Server deployment of WildDuck mail server.

## 📋 Overview

This folder contains production-ready MongoDB 7.0 configuration files optimized for high-capacity servers:

**Server Configuration:**

- Total RAM: 128GB (96GB available for native services after 32GB VMware allocation)
- Storage: 10TB RAID6 SSD (very fast, high IOPS, optimized for maximum document storage)
- MongoDB allocation: ~47GB RAM (50% of available native RAM)
- PostgreSQL uses remaining ~48GB RAM (Mail Box Indexer only)
- Logging: Minimal (optimized for disk space conservation)
- **Goal:** Maximize email document storage - millions of emails per WildDuck user
- **SSD Performance:** Excellent for GridFS (email attachments), low-latency random I/O
- **Effective Storage:** ~13TB with zstd compression (30% gain over uncompressed)

**Configuration Files:**

- **`mongod.conf`** - Main MongoDB configuration (performance tuned for 96GB RAM, RAID6 SSD, minimal logging)
- **`init_database.js`** - Database initialization script (creates databases, users, collections, indexes)
- **`backup_database.ps1`** - Automated backup script with compression and rotation (30-day retention, auto log cleanup)
- **`cleanup_logs.ps1`** - Weekly log cleanup script (keeps only 7 days of logs)

**Storage Optimization for Maximum Documents:**

**Compression Strategy:**

- **zstd compression:** 30% better than snappy = 30% more emails in same space
- **Index compression:** 20-50% savings on index storage
- **Combined effect:** ~13TB effective storage from 10TB physical

**What This Means:**

- **10TB physical** → **~13TB effective** with zstd compression
- Store millions of emails per WildDuck user account
- Each email (avg 50KB) → ~260 million emails possible
- GridFS attachments compressed efficiently
- Indexes use 20-50% less space

**RAID6 SSD Benefits:**

- **GridFS Performance:** Fast attachment storage/retrieval
- **Random I/O:** Excellent for millions of small email documents
- **High IOPS:** Handles thousands of concurrent IMAP/SMTP operations
- **Data Protection:** 2-drive failure tolerance
- **Longevity:** Large cache (47GB) reduces disk writes, extends SSD life

## 🚀 Quick Start

### 1. Prerequisites

- MongoDB 7.0 installed on Windows Server
- Installation path: `C:\Program Files\MongoDB\Server\7.0`
- Data directory: `C:\MongoDB\data` (recommended) or `C:\Program Files\MongoDB\Server\7.0\data`
- Administrative access to Windows Server

### 2. Deploy Configuration File

#### Step 1: Locate MongoDB Configuration File

Open PowerShell as Administrator:

```powershell
# Check MongoDB service status
Get-Service MongoDB

# Default config file location:
# C:\Program Files\MongoDB\Server\7.0\bin\mongod.cfg
```

#### Step 2: Backup Existing Configuration

```powershell
# Navigate to MongoDB bin directory
cd "C:\Program Files\MongoDB\Server\7.0\bin"

# Backup existing config
Copy-Item mongod.cfg mongod.cfg.backup
```

#### Step 3: Copy New Configuration File

Copy the configuration file from this folder:

```powershell
# Copy mongod.conf
Copy-Item "path\to\wildduck-dockerized\mongodb\mongod.conf" "C:\Program Files\MongoDB\Server\7.0\bin\mongod.cfg" -Force
```

#### Step 4: Create Required Directories

```powershell
# Create data directory
New-Item -ItemType Directory -Path "C:\MongoDB\data" -Force

# Create log directory
New-Item -ItemType Directory -Path "C:\MongoDB\log" -Force

# Create backup directory
New-Item -ItemType Directory -Path "C:\MongoDB\backups" -Force

# Grant MongoDB service write permissions (if needed)
$Acl = Get-Acl "C:\MongoDB"
$Permission = "NT SERVICE\MongoDB", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $Permission
$Acl.AddAccessRule($AccessRule)
Set-Acl "C:\MongoDB" $Acl
```

#### Step 5: Customize for Your Environment

The configuration file is pre-tuned for your high-capacity server:

1. **Memory Settings** (optimized for 96GB available RAM):
   - `cacheSizeGB: 47` - 50% of available RAM minus 1GB
   - Large cache = more documents in RAM = faster access + less disk wear
   - With 47GB cache: Can keep ~100M-500M documents hot in memory
   - Reduces disk I/O, extends SSD lifespan

2. **Network Settings** (`net.bindIp`):
   - **IMPORTANT**: Change from `0.0.0.0` to specific IPs for production
   - Examples:
     - Local only: `127.0.0.1`
     - Local + Docker: `127.0.0.1,172.17.0.1`
     - Local + specific IP: `127.0.0.1,192.168.1.100`

3. **Storage Settings** (optimized for maximum document storage on 10TB RAID6 SSD):
   - `maxIncomingConnections: 5000` - High-capacity connections
   - `blockCompressor: zstd` - **Critical:** 30% better compression = 30% more emails
   - `prefixCompression: true` - Index compression saves 20-50% space
   - `journalCompressor: snappy` - Fast journal writes (journal is temporary)
   - Data directory: `C:\MongoDB\data`
   - **Result:** ~13TB effective storage capacity (30% compression gain)
   - **Capacity:** ~260 million average emails (50KB each) on 10TB storage

4. **Logging Settings** (minimized for disk space):
   - `logRotate: rename` - MongoDB renames old logs on rotation
   - `slowOpThresholdMs: 1000` - Only log operations slower than 1 second
   - `slowOpSampleRate: 0.1` - Sample only 10% of slow operations
   - Profiling database kept minimal for disk space conservation

#### Step 6: Restart MongoDB

```powershell
# Restart MongoDB service
Restart-Service MongoDB

# Verify service is running
Get-Service MongoDB

# Check logs for errors
Get-Content "C:\MongoDB\log\mongod.log" -Tail 50
```

### 3. Initialize Databases and Users

#### Step 1: First-Time Setup (Without Authentication)

If this is a fresh MongoDB installation without authentication enabled yet:

```powershell
# Navigate to MongoDB bin directory
cd "C:\Program Files\MongoDB\Server\7.0\bin"

# Temporarily disable authentication
# Edit mongod.cfg and comment out: security.authorization: enabled
# Then restart: Restart-Service MongoDB

# Run initialization script
.\mongosh.exe --file "path\to\wildduck-dockerized\mongodb\init_database.js"

# Re-enable authentication
# Edit mongod.cfg and uncomment: security.authorization: enabled
# Then restart: Restart-Service MongoDB
```

#### Step 2: Run Initialization Script

```powershell
# Navigate to MongoDB bin directory
cd "C:\Program Files\MongoDB\Server\7.0\bin"

# Run initialization script
.\mongosh.exe --host localhost --port 27017 --file "path\to\wildduck-dockerized\mongodb\init_database.js"
```

The script will create:

- Admin user: `admin` / `admin-password-change-me`
- WildDuck database: `wildduck`
- WildDuck user: `wildduck` / `wildduck-password`
- Zone-MTA database: `zone-mta` (optional)
- Zone-MTA user: `zonemta` / `zonemta-password` (optional)
- Essential collections and indexes

#### Step 3: Change Default Passwords (CRITICAL!)

```powershell
# Connect as admin
.\mongosh.exe -u admin -p --authenticationDatabase admin

# Inside mongosh, change passwords
use admin
db.changeUserPassword("admin", "your-strong-admin-password")

use wildduck
db.changeUserPassword("wildduck", "your-strong-wildduck-password")

use zone-mta
db.changeUserPassword("zonemta", "your-strong-zonemta-password")

exit
```

#### Step 4: Verify Setup

```powershell
# Test connection with new credentials
.\mongosh.exe "mongodb://wildduck:your-strong-wildduck-password@localhost:27017/wildduck?authSource=wildduck"

# Inside mongosh, verify collections
show collections
db.users.find()  # Should be empty initially
exit
```

### 4. Set Up Automated Backups

#### Step 1: Copy Backup Script

```powershell
# Copy backup script to MongoDB directory
Copy-Item "path\to\wildduck-dockerized\mongodb\backup_database.ps1" "C:\MongoDB\backup_database.ps1"
```

#### Step 2: Configure Authentication

Set MongoDB admin password as environment variable:

```powershell
# For current session only
$env:MONGO_PASSWORD = "your-strong-admin-password"

# For permanent (user-level)
[System.Environment]::SetEnvironmentVariable('MONGO_PASSWORD', 'your-strong-admin-password', 'User')

# For permanent (system-level, requires admin)
[System.Environment]::SetEnvironmentVariable('MONGO_PASSWORD', 'your-strong-admin-password', 'Machine')
```

#### Step 3: Test Backup Script

```powershell
# Run backup manually to test
cd "C:\MongoDB"
.\backup_database.ps1

# Check backup was created
Get-ChildItem "C:\MongoDB\backups" | Sort-Object LastWriteTime -Descending
```

#### Step 4: Schedule Daily Backups

Create scheduled task for daily backups at 2 AM:

```powershell
# Create scheduled task
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\MongoDB\backup_database.ps1"

$Trigger = New-ScheduledTaskTrigger -Daily -At 2am

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "MongoDB-WildDuck-Backup" `
    -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings `
    -Description "Daily backup of WildDuck MongoDB database"
```

Verify scheduled task:

```powershell
# List scheduled tasks
Get-ScheduledTask | Where-Object {$_.TaskName -like "*MongoDB*"}

# Test run the task
Start-ScheduledTask -TaskName "MongoDB-WildDuck-Backup"

# Check task history
Get-ScheduledTask -TaskName "MongoDB-WildDuck-Backup" | Get-ScheduledTaskInfo
```

### 5. Set Up Weekly Log Cleanup

To minimize disk usage, schedule weekly log cleanup:

#### Step 1: Copy Cleanup Script

```powershell
# Copy cleanup script to MongoDB directory
Copy-Item "path\to\wildduck-dockerized\mongodb\cleanup_logs.ps1" "C:\MongoDB\cleanup_logs.ps1"
```

#### Step 2: Test Cleanup Script

```powershell
# Run cleanup manually to test
cd "C:\MongoDB"
.\cleanup_logs.ps1

# Check which logs would be deleted (dry run)
.\cleanup_logs.ps1 -RetentionDays 7
```

#### Step 3: Schedule Weekly Cleanup

Create scheduled task for weekly cleanup (Sundays at 3 AM):

```powershell
# Create scheduled task for log cleanup
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\MongoDB\cleanup_logs.ps1"

$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

Register-ScheduledTask -TaskName "MongoDB-Log-Cleanup" `
    -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings `
    -Description "Weekly cleanup of old MongoDB log files to save disk space"
```

Verify scheduled task:

```powershell
# List log cleanup task
Get-ScheduledTask -TaskName "MongoDB-Log-Cleanup"

# Test run the task
Start-ScheduledTask -TaskName "MongoDB-Log-Cleanup"
```

### 6. Configure Windows Firewall

If you need remote access to MongoDB:

```powershell
# Open PowerShell as Administrator

# Create firewall rule for MongoDB
New-NetFirewallRule -DisplayName "MongoDB WildDuck" `
    -Direction Inbound -Protocol TCP -LocalPort 27017 -Action Allow `
    -Profile Domain,Private

# Verify rule was created
Get-NetFirewallRule -DisplayName "MongoDB WildDuck"
```

**SECURITY WARNING**: Only allow MongoDB access from trusted IPs in production!

For more restrictive access:

```powershell
# Allow only from specific IP
New-NetFirewallRule -DisplayName "MongoDB WildDuck - App Server" `
    -Direction Inbound -Protocol TCP -LocalPort 27017 -Action Allow `
    -RemoteAddress "192.168.1.100" -Profile Domain,Private

# Allow from subnet
New-NetFirewallRule -DisplayName "MongoDB WildDuck - Local Network" `
    -Direction Inbound -Protocol TCP -LocalPort 27017 -Action Allow `
    -RemoteAddress "192.168.1.0/24" -Profile Domain,Private
```

### 7. Test Connections

**From Windows (Local)**:

```powershell
# Test with mongosh
cd "C:\Program Files\MongoDB\Server\7.0\bin"
.\mongosh.exe "mongodb://wildduck:password@localhost:27017/wildduck?authSource=wildduck"
```

**From Mac/Linux (Remote)**:

```bash
# Test port is open
nc -zv YOUR_SERVER_IP 27017

# Connect with mongosh
mongosh "mongodb://wildduck:password@YOUR_SERVER_IP:27017/wildduck?authSource=wildduck"

# Or test with Python
python3 -c "from pymongo import MongoClient; client = MongoClient('mongodb://wildduck:password@YOUR_SERVER_IP:27017/wildduck?authSource=wildduck'); print('Connected!'); print(client.server_info())"
```

**From Docker Container**:

```bash
# Test connection from WildDuck container
docker exec -it wildduck sh -c 'mongosh $MONGO_URL --eval "db.adminCommand(\"ping\")"'

# Or use mongo connection string
docker exec -it wildduck sh -c 'mongosh "mongodb://wildduck:password@host.docker.internal:27017/wildduck?authSource=wildduck" --eval "db.stats()"'
```

**Verify Network Connectivity**:

```powershell
# Check MongoDB is listening on all interfaces
netstat -an | Select-String ":27017"

# Should show:
# TCP    0.0.0.0:27017          0.0.0.0:0              LISTENING
# TCP    [::]:27017             [::]:0                 LISTENING
```

## 📊 Configuration Details

### mongod.conf Settings

**Network Settings**:

- `port: 27017` - Default MongoDB port
- `bindIp: 0.0.0.0` - Listen on all interfaces (CHANGE for production!)
- `maxIncomingConnections: 1000` - Maximum concurrent connections
- `compression: snappy,zstd` - Wire protocol compression

**Security Settings**:

- `authorization: enabled` - Require authentication
- `javascriptEnabled: false` - Disable server-side JavaScript (better security)

**Storage Settings**:

- `dbPath: C:\MongoDB\data` - Database storage location
- `engine: wiredTiger` - Storage engine (default and recommended)
- `cacheSizeGB: 3` - WiredTiger cache size (adjust based on RAM)
- `journalCompressor: snappy` - Journal compression
- `blockCompressor: snappy` - Collection compression

**Logging**:

- `path: C:\MongoDB\log\mongod.log` - Log file location
- `verbosity: 0` - Log level (0=Info, 1-5=Debug)
- `logRotate: reopen` - Log rotation method

**Performance Profiling**:

- `mode: slowOp` - Log slow operations only
- `slowOpThresholdMs: 100` - Operations slower than 100ms are logged

### init_database.js

Creates and configures:

**Admin User**:

- Username: `admin`
- Password: `admin-password-change-me` (CHANGE THIS!)
- Roles: `root` (full admin access)
- Database: `admin`

**WildDuck User**:

- Username: `wildduck`
- Password: `wildduck-password` (CHANGE THIS!)
- Roles: `dbOwner` on `wildduck` database
- Database: `wildduck`

**Collections Created**:

- `users` - User accounts
- `addresses` - Email addresses
- `mailboxes` - IMAP folders
- `messages` - Email messages
- `attachments.files` - GridFS file metadata
- `attachments.chunks` - GridFS file chunks
- `threads` - Email threads
- `autoreplies` - Auto-reply rules
- `filters` - Email filters
- `domainaliases` - Domain aliases
- `auditlog` - Audit log

**Indexes Created**:

- User indexes: `username`, `unameview`
- Address indexes: `addrview`, `user`
- Mailbox indexes: `user+path`
- Message indexes: `user+mailbox+uid`, `user+searchable`, `exp` (TTL), `rdate`

### backup_database.ps1

Features:

- Single database or full backup (all databases)
- Gzip compression for efficient storage
- Automatic .zip archive creation
- Oplog backup for point-in-time recovery (full backup only)
- 30-day retention by default (configurable)
- Detailed logging with timestamps
- Database size reporting
- Error handling with exit codes

Backup location: `C:\MongoDB\backups\`
Backup filename format: `wildduck_YYYY-MM-DD_HHmmss.zip`

Usage examples:

```powershell
# Backup wildduck database (default)
.\backup_database.ps1

# Backup specific database
.\backup_database.ps1 -Database "zone-mta"

# Backup all databases with oplog
.\backup_database.ps1 -FullBackup

# Custom retention
.\backup_database.ps1 -RetentionDays 7

# Show help
.\backup_database.ps1 -Help
```

## 🔐 Security Checklist

- [ ] Changed default admin password from 'admin-password-change-me'
- [ ] Changed default wildduck password from 'wildduck-password'
- [ ] Changed bindIp from 0.0.0.0 to specific IPs
- [ ] Enabled authentication (security.authorization: enabled)
- [ ] Configured firewall to allow only necessary IPs
- [ ] Set MONGO_PASSWORD environment variable for backups
- [ ] Tested remote connections work
- [ ] Verified backups run successfully
- [ ] Scheduled automated backups
- [ ] Disabled JavaScript execution (javascriptEnabled: false)
- [ ] Reviewed log files for unauthorized access attempts
- [ ] Set up monitoring (MongoDB Compass or Ops Manager)

## 🧪 Testing and Verification

### Check MongoDB is Running

```powershell
# Service status
Get-Service MongoDB

# Listening ports
netstat -an | Select-String ":27017"

# Should show:
# TCP    0.0.0.0:27017          0.0.0.0:0              LISTENING
# TCP    [::]:27017             [::]:0                 LISTENING
```

### Verify Configuration Loaded

```powershell
# Connect to MongoDB
cd "C:\Program Files\MongoDB\Server\7.0\bin"
.\mongosh.exe -u admin -p --authenticationDatabase admin

# Inside mongosh, check settings
db.adminCommand({ getCmdLineOpts: 1 })
db.serverStatus().wiredTiger.cache
db.runCommand({ getParameter: 1, authenticationMechanisms: 1 })

exit
```

### Test User Permissions

```powershell
# Connect as wildduck user
.\mongosh.exe "mongodb://wildduck:password@localhost:27017/wildduck?authSource=wildduck"

# Inside mongosh, test permissions
db.test_collection.insertOne({ test: "data" })
db.test_collection.find()
db.test_collection.drop()

exit
```

### Verify Collections and Indexes

```powershell
# Connect to wildduck database
.\mongosh.exe "mongodb://wildduck:password@localhost:27017/wildduck?authSource=wildduck"

# Inside mongosh, list collections
show collections

# Check indexes on critical collections
db.users.getIndexes()
db.messages.getIndexes()
db.addresses.getIndexes()

exit
```

### Monitor Performance

```powershell
# Connect to admin database
.\mongosh.exe -u admin -p --authenticationDatabase admin

# Inside mongosh, view slow queries
use wildduck
db.system.profile.find().sort({ ts: -1 }).limit(10).pretty()

# View current operations
db.currentOp()

# View server status
db.serverStatus()

# View connection stats
db.serverStatus().connections

# View cache statistics
db.serverStatus().wiredTiger.cache

exit
```

## 🐛 Troubleshooting

### MongoDB Won't Start

```powershell
# Check Windows Event Viewer
Get-EventLog -LogName Application -Source MongoDB -Newest 20

# Check MongoDB logs
Get-Content "C:\MongoDB\log\mongod.log" -Tail 100

# Common issues:
# 1. Port 27017 already in use
# 2. Data directory doesn't exist or no write permissions
# 3. Syntax error in mongod.cfg
# 4. Corrupted data files (requires repair)
```

Fix corrupted data:

```powershell
# Stop MongoDB service
Stop-Service MongoDB

# Run repair (WARNING: Can take a long time and requires 2x disk space)
& "C:\Program Files\MongoDB\Server\7.0\bin\mongod.exe" --dbpath "C:\MongoDB\data" --repair

# Restart service
Start-Service MongoDB
```

### Remote Connection Refused

```powershell
# Verify MongoDB is listening on all interfaces
netstat -an | Select-String ":27017"
# Should show 0.0.0.0:27017, not 127.0.0.1:27017

# Verify firewall rule exists
Get-NetFirewallRule -DisplayName "MongoDB*"

# Verify bindIp in mongod.cfg
Get-Content "C:\Program Files\MongoDB\Server\7.0\bin\mongod.cfg" | Select-String "bindIp"

# Test from remote machine
Test-NetConnection -ComputerName YOUR_SERVER_IP -Port 27017
```

### Authentication Failed

```powershell
# Verify user exists
.\mongosh.exe -u admin -p --authenticationDatabase admin
use wildduck
db.getUsers()
exit

# Common issues:
# 1. Wrong password
# 2. Wrong authSource in connection string
# 3. User doesn't have permissions on database
# 4. Authentication not enabled in mongod.cfg
```

Reset user password:

```powershell
# Connect as admin
.\mongosh.exe -u admin -p --authenticationDatabase admin

# Reset password
use wildduck
db.changeUserPassword("wildduck", "new-strong-password")

exit
```

### Backup Script Fails

```powershell
# Run backup script manually to see errors
cd "C:\MongoDB"
.\backup_database.ps1

# Check backup log
Get-Content "C:\MongoDB\backups\backup_log_*.txt" -Tail 50

# Common issues:
# 1. MONGO_PASSWORD not set
# 2. mongodump.exe not found
# 3. Insufficient disk space
# 4. MongoDB service not running
# 5. Authentication failed
```

Set password and retry:

```powershell
# Set password
$env:MONGO_PASSWORD = "your-admin-password"

# Retry backup
.\backup_database.ps1
```

### WildDuck Can't Connect

Check WildDuck configuration:

```bash
# From docker-compose.yml, verify MONGO_URL
docker-compose config | grep MONGO_URL

# Should be something like:
# MONGO_URL=mongodb://wildduck:password@host.docker.internal:27017/wildduck?authSource=wildduck
```

Test from Docker container:

```bash
# Execute mongosh from inside container
docker exec -it wildduck sh -c 'apk add mongodb-tools && mongosh "$MONGO_URL" --eval "db.stats()"'
```

Check WildDuck logs:

```bash
# View WildDuck logs for MongoDB errors
docker-compose logs -f wildduck | grep -i mongo
```

### Performance Issues

```powershell
# Connect to admin
.\mongosh.exe -u admin -p --authenticationDatabase admin

# Inside mongosh, check performance
# View slow queries
use wildduck
db.setProfilingLevel(1, { slowms: 100 })  # Log queries >100ms
db.system.profile.find().sort({ ts: -1 }).limit(10)

# Check cache hit ratio (should be >90%)
db.serverStatus().wiredTiger.cache.bytes_currently_in_the_cache
db.serverStatus().wiredTiger.cache.maximum_bytes_configured

# Check index usage
db.users.aggregate([{ $indexStats: {} }])
db.messages.aggregate([{ $indexStats: {} }])

exit
```

Optimize performance:

1. **Increase cache size** (if you have more RAM):
   - Edit mongod.cfg: `cacheSizeGB: 7` (for 16GB RAM)
   - Restart: `Restart-Service MongoDB`

2. **Add missing indexes**:
   - Review slow queries in `db.system.profile`
   - Create indexes for frequently queried fields

3. **Enable compression**:
   - Already enabled by default (snappy)
   - Consider zstd for better compression (slower)

4. **Use SSD storage**:
   - Move data directory to SSD if on HDD
   - Update `dbPath` in mongod.cfg

## 📚 Connection Strings

### Local Development (Windows)

```text
mongodb://wildduck:password@localhost:27017/wildduck?authSource=wildduck
```

### Docker on Windows Host

```text
mongodb://wildduck:password@host.docker.internal:27017/wildduck?authSource=wildduck
```

### Remote Access

```text
mongodb://wildduck:password@YOUR_SERVER_IP:27017/wildduck?authSource=wildduck
```

### With Replica Set (High Availability)

```text
mongodb://wildduck:password@server1:27017,server2:27017,server3:27017/wildduck?authSource=wildduck&replicaSet=wildduck-rs
```

### Connection String Options

Common options you can add to connection strings:

- `authSource=wildduck` - Authentication database
- `replicaSet=wildduck-rs` - Replica set name
- `retryWrites=true` - Retry failed writes
- `w=majority` - Write concern (wait for majority of replica set)
- `readPreference=primaryPreferred` - Read from primary, fall back to secondary
- `maxPoolSize=100` - Maximum connection pool size
- `ssl=true` - Use SSL/TLS connection
- `appName=WildDuck` - Application name for monitoring

Example with all options:

```text
mongodb://wildduck:password@server1:27017,server2:27017/wildduck?authSource=wildduck&replicaSet=wildduck-rs&retryWrites=true&w=majority&readPreference=primaryPreferred&maxPoolSize=100&appName=WildDuck
```

## 🔄 Backup and Restore

### Backup Single Database

```powershell
# Using backup script
cd "C:\MongoDB"
.\backup_database.ps1 -Database "wildduck"

# Manual backup with mongodump
cd "C:\Program Files\MongoDB\Server\7.0\bin"
$env:MONGO_PASSWORD = "admin-password"
.\mongodump.exe --host localhost --port 27017 --username admin --password $env:MONGO_PASSWORD --authenticationDatabase admin --db wildduck --out "C:\MongoDB\backups\manual" --gzip
```

### Backup All Databases

```powershell
# Using backup script (includes oplog)
cd "C:\MongoDB"
.\backup_database.ps1 -FullBackup

# Manual backup
cd "C:\Program Files\MongoDB\Server\7.0\bin"
$env:MONGO_PASSWORD = "admin-password"
.\mongodump.exe --host localhost --port 27017 --username admin --password $env:MONGO_PASSWORD --authenticationDatabase admin --out "C:\MongoDB\backups\full" --oplog --gzip
```

### Restore Database

```powershell
# Extract backup archive
Expand-Archive -Path "C:\MongoDB\backups\wildduck_2025-10-05_020000.zip" -DestinationPath "C:\Temp\restore"

# Restore with mongorestore
cd "C:\Program Files\MongoDB\Server\7.0\bin"
$env:MONGO_PASSWORD = "admin-password"
.\mongorestore.exe --host localhost --port 27017 --username admin --password $env:MONGO_PASSWORD --authenticationDatabase admin --db wildduck --gzip "C:\Temp\restore\wildduck"

# Or restore from .zip directly
.\mongorestore.exe --host localhost --port 27017 --username admin --password $env:MONGO_PASSWORD --authenticationDatabase admin --gzip --archive="C:\MongoDB\backups\wildduck_2025-10-05_020000.zip"
```

### Point-in-Time Restore (Full Backup with Oplog)

```powershell
# Extract full backup
Expand-Archive -Path "C:\MongoDB\backups\full_2025-10-05_020000.zip" -DestinationPath "C:\Temp\restore"

# Restore with oplog replay
cd "C:\Program Files\MongoDB\Server\7.0\bin"
$env:MONGO_PASSWORD = "admin-password"
.\mongorestore.exe --host localhost --port 27017 --username admin --password $env:MONGO_PASSWORD --authenticationDatabase admin --oplogReplay --gzip "C:\Temp\restore"
```

## 🎯 Production Deployment Checklist

### Before Going Live

- [ ] MongoDB 7.0 installed and running
- [ ] Configuration file deployed (mongod.cfg)
- [ ] Data directory created with proper permissions
- [ ] Log directory created
- [ ] Backup directory created
- [ ] Database initialized (init_database.js)
- [ ] All default passwords changed
- [ ] bindIp configured with specific IPs (not 0.0.0.0)
- [ ] Authentication enabled
- [ ] Firewall configured for necessary IPs only
- [ ] Remote connections tested
- [ ] Backup script tested
- [ ] Automated backups scheduled
- [ ] Monitoring configured (Compass, Ops Manager, or Prometheus)
- [ ] Log rotation configured
- [ ] Disk space monitoring set up

### High Availability (Optional)

For production environments requiring high availability:

1. **Set up Replica Set** (minimum 3 nodes):
   - Primary: Handles all writes
   - Secondary 1: Replicates from primary
   - Secondary 2 or Arbiter: Voting member for elections

2. **Configure Replica Set in mongod.cfg**:

   ```yaml
   replication:
     replSetName: wildduck-rs
     oplogSizeMB: 10240
   ```

3. **Initialize Replica Set**:

   ```javascript
   rs.initiate({
     _id: "wildduck-rs",
     members: [
       { _id: 0, host: "server1:27017", priority: 2 },
       { _id: 1, host: "server2:27017", priority: 1 },
       { _id: 2, host: "server3:27017", arbiterOnly: true }
     ]
   })
   ```

4. **Update Connection Strings**:

   ```text
   mongodb://wildduck:password@server1:27017,server2:27017,server3:27017/wildduck?authSource=wildduck&replicaSet=wildduck-rs
   ```

### Performance Optimization

1. **Memory**: Adjust `cacheSizeGB` based on total RAM
2. **Disk**: Use SSD for `dbPath` and journal
3. **Indexes**: Monitor and create indexes for frequently queried fields
4. **Compression**: Use snappy (fast) or zstd (better compression)
5. **Connection Pooling**: Configure in WildDuck application
6. **Monitoring**: Set up alerts for slow queries, disk space, memory usage

## 📖 Additional Resources

### MongoDB Documentation

- [MongoDB 7.0 Documentation](https://docs.mongodb.com/manual/)
- [Configuration File Options](https://docs.mongodb.com/manual/reference/configuration-options/)
- [WiredTiger Storage Engine](https://docs.mongodb.com/manual/core/wiredtiger/)
- [Security Checklist](https://docs.mongodb.com/manual/administration/security-checklist/)
- [Backup Methods](https://docs.mongodb.com/manual/core/backups/)
- [Replication](https://docs.mongodb.com/manual/replication/)

### WildDuck Documentation

- [GitHub Repository](https://github.com/nodemailer/wildduck)
- [Official Website](https://wildduck.email/)
- [API Documentation](https://docs.wildduck.email/)

### Tools

- [MongoDB Compass](https://www.mongodb.com/products/compass) - GUI for MongoDB
- [MongoDB Ops Manager](https://www.mongodb.com/products/ops-manager) - Monitoring and automation
- [Studio 3T](https://studio3t.com/) - MongoDB IDE

## 🔄 Maintenance Tasks

### Daily

- Automated backups (via scheduled task)
- Monitor service status

### Weekly

- Review backup logs for failures
- Check disk space (data, logs, backups)
- Review slow query log (`db.system.profile`)

### Monthly

- Rotate old backups manually if needed
- Review and update user passwords per security policy
- Update MongoDB to latest patch version
- Review firewall rules and access logs

### Quarterly

- Compact databases: `db.runCommand({ compact: "collection_name" })`
- Review and optimize indexes
- Test backup restoration process
- Security audit of users and permissions
- Review performance metrics and adjust configuration

## 💡 Tips

- **Memory Tuning**: Set `cacheSizeGB` to 50% of (RAM - 1GB) for dedicated MongoDB servers
- **Connection Pooling**: WildDuck handles this automatically, but monitor `maxIncomingConnections`
- **Compression**: Snappy is fast and saves ~30% disk space; consider zstd for better compression
- **Monitoring**: Use MongoDB Compass for real-time monitoring and query profiling
- **Backup Testing**: Regularly test backup restoration to ensure backups are valid
- **Replica Sets**: For production, use 3-node replica set for high availability
- **Documentation**: Keep a log of configuration changes and why they were made

## 🆘 Support

If you encounter issues:

1. Check MongoDB logs: `C:\MongoDB\log\mongod.log`
2. Check Windows Event Viewer: Application logs with source "MongoDB"
3. Verify configuration: Review mongod.cfg for syntax errors
4. Review this README's troubleshooting section
5. Consult official MongoDB documentation
6. Check WildDuck GitHub issues for similar problems

---

**Last Updated**: 2025-10-05
**MongoDB Version**: 7.0
**Target OS**: Windows Server
**Maintainer**: WildDuck Deployment
