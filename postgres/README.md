# PostgreSQL Configuration for Mail Box Indexer

Complete PostgreSQL setup files for Windows Server deployment of the Mail Box Indexer database.

## 📋 Overview

This folder contains production-ready PostgreSQL 17 configuration files optimized for high-capacity servers:

**Server Configuration:**
- Total RAM: 128GB (96GB available for native services after 32GB VMware allocation)
- Storage: 10TB RAID6 SSD (very fast, high IOPS, optimized for maximum email storage)
- PostgreSQL allocation: ~48GB RAM (50% of available native RAM)
- MongoDB uses remaining ~48GB RAM (stores WildDuck emails, attachments, user data)
- Logging: Minimal (optimized for disk space conservation)
- **Goal:** Maximize MongoDB document storage capacity for millions of emails per user
- **SSD Performance:** Excellent random I/O, low latency, high throughput

**Configuration Files:**
- **`postgresql.conf`** - Main PostgreSQL configuration (performance tuned for 96GB RAM)
- **`pg_hba.conf`** - Client authentication and security rules
- **`init_database.sql`** - Database initialization script (creates database, user, extensions)
- **`backup_database.ps1`** - Automated backup script with rotation (30-day retention)

## 🚀 Quick Start

### 1. Prerequisites

- PostgreSQL 17 installed on Windows Server
- Installation path: `C:\Program Files\PostgreSQL\17`
- Data directory: `C:\PostgreSQL\data` (or `C:\Program Files\PostgreSQL\17\data`)
- Administrative access to Windows Server

### 2. Deploy Configuration Files

**Step 1: Locate PostgreSQL Data Directory**

Open PowerShell as Administrator:

```powershell
# Check PostgreSQL service status
Get-Service postgresql-x64-17

# Find data directory (default locations)
# Option A: C:\PostgreSQL\data
# Option B: C:\Program Files\PostgreSQL\17\data
```

**Step 2: Backup Existing Configuration**

```powershell
# Navigate to PostgreSQL data directory
cd "C:\PostgreSQL\data"  # or C:\Program Files\PostgreSQL\17\data

# Backup existing files
Copy-Item postgresql.conf postgresql.conf.backup
Copy-Item pg_hba.conf pg_hba.conf.backup
```

**Step 3: Copy New Configuration Files**

Copy the configuration files from this folder to your PostgreSQL data directory:

```powershell
# Copy postgresql.conf
Copy-Item "path\to\wildduck-dockerized\postgres\postgresql.conf" "C:\PostgreSQL\data\postgresql.conf" -Force

# Copy pg_hba.conf
Copy-Item "path\to\wildduck-dockerized\postgres\pg_hba.conf" "C:\PostgreSQL\data\pg_hba.conf" -Force
```

**Step 4: Customize for Your Environment**

The configuration files are pre-tuned for your high-capacity server:

1. **postgresql.conf** (optimized for 96GB RAM + RAID6 SSD):
   - `shared_buffers = 24GB` (25% of 96GB)
   - `effective_cache_size = 72GB` (75% of 96GB)
   - `work_mem = 64MB` (for 500 connections)
   - `maintenance_work_mem = 4GB` (for large indexes)
   - `max_connections = 500` (high-capacity)
   - `max_wal_size = 16GB` (for 10TB storage)
   - Parallel workers: 16 (for multi-core CPU)
   - **SSD optimizations:** `random_page_cost = 1.0`, `effective_io_concurrency = 300`

2. **pg_hba.conf**:
   - **IMPORTANT**: Replace placeholder IPs with your actual server IPs
   - For Docker: Verify Docker network range (default: 172.17.0.0/16)
   - For remote access: Add specific IP addresses or subnets
   - See inline comments in pg_hba.conf for examples

**Step 5: Restart PostgreSQL**

```powershell
# Restart PostgreSQL service
Restart-Service postgresql-x64-17

# Verify service is running
Get-Service postgresql-x64-17

# Check logs for errors
Get-Content "C:\PostgreSQL\data\log\postgresql-*.log" -Tail 50
```

### 3. Initialize Database

**Step 1: Run Initialization Script**

Open PowerShell and run the SQL script:

```powershell
# Navigate to PostgreSQL bin directory
cd "C:\Program Files\PostgreSQL\17\bin"

# Run initialization script (you'll be prompted for postgres password)
.\psql.exe -U postgres -f "path\to\wildduck-dockerized\postgres\init_database.sql"
```

**Step 2: Verify Database Creation**

```powershell
# Connect to database
.\psql.exe -U postgres -d mail_box_indexer

# Inside psql, run verification queries
\l                          # List databases
\du                         # List users
\dx                         # List extensions
\q                          # Quit

# Or verify from command line
.\psql.exe -U postgres -d mail_box_indexer -c "\dx"
```

**Step 3: Change Default Password (CRITICAL!)**

```powershell
# Connect as postgres
.\psql.exe -U postgres -d mail_box_indexer

# Inside psql, change ponder user password
ALTER USER ponder WITH PASSWORD 'your-strong-password-here';
\q
```

**Step 4: Test Connection**

```powershell
# Test connection as ponder user
.\psql.exe -U ponder -d mail_box_indexer

# You'll be prompted for the password you just set
# If successful, you'll see the psql prompt

# Test a simple query
SELECT version();
\q
```

### 4. Set Up Automated Backups

**Step 1: Create Backup Directory**

```powershell
# Create backup directory
New-Item -ItemType Directory -Path "C:\PostgreSQL\backups" -Force
```

**Step 2: Copy Backup Script**

```powershell
# Copy backup script to a permanent location
Copy-Item "path\to\wildduck-dockerized\postgres\backup_database.ps1" "C:\PostgreSQL\backup_database.ps1"
```

**Step 3: Configure Password Authentication**

Create a `.pgpass` file for password-less backups:

```powershell
# Create .pgpass file in your user profile
# Format: hostname:port:database:username:password
$pgpassContent = "localhost:5432:mail_box_indexer:ponder:your-strong-password-here"
$pgpassPath = "$env:APPDATA\postgresql\pgpass.conf"

# Create directory if it doesn't exist
New-Item -ItemType Directory -Path "$env:APPDATA\postgresql" -Force

# Write password file
Set-Content -Path $pgpassPath -Value $pgpassContent

# Or set environment variable (less secure)
[System.Environment]::SetEnvironmentVariable('PGPASSWORD', 'your-strong-password-here', 'User')
```

**Step 4: Test Backup Script**

```powershell
# Run backup manually to test
cd "C:\PostgreSQL"
.\backup_database.ps1

# Check backup was created
Get-ChildItem "C:\PostgreSQL\backups" | Sort-Object LastWriteTime -Descending
```

**Step 5: Schedule with Task Scheduler**

Create scheduled task for daily backups at 2 AM:

```powershell
# Create scheduled task
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\PostgreSQL\backup_database.ps1"
$Trigger = New-ScheduledTaskTrigger -Daily -At 2am
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "PostgreSQL-MailBoxIndexer-Backup" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Daily backup of mail_box_indexer database"
```

Verify scheduled task:

```powershell
# List scheduled tasks
Get-ScheduledTask | Where-Object {$_.TaskName -like "*PostgreSQL*"}

# Test run the task
Start-ScheduledTask -TaskName "PostgreSQL-MailBoxIndexer-Backup"

# Check task history
Get-ScheduledTask -TaskName "PostgreSQL-MailBoxIndexer-Backup" | Get-ScheduledTaskInfo
```

### 5. Configure Windows Firewall

If you need remote access to PostgreSQL:

```powershell
# Open PowerShell as Administrator

# Create firewall rule for PostgreSQL
New-NetFirewallRule -DisplayName "PostgreSQL Mail Box Indexer" -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow -Profile Domain,Private

# Verify rule was created
Get-NetFirewallRule -DisplayName "PostgreSQL Mail Box Indexer"
```

### 6. Test Remote Connection

**From Mac/Linux**:

```bash
# Test port is open
nc -zv YOUR_SERVER_IP 5432

# Connect with psql
psql -h YOUR_SERVER_IP -U ponder -d mail_box_indexer

# Or test with Python
python3 -c "import psycopg2; conn = psycopg2.connect('postgresql://ponder:password@YOUR_SERVER_IP:5432/mail_box_indexer'); print('Connected!'); conn.close()"
```

**From Windows**:

```powershell
# Test port is open
Test-NetConnection -ComputerName YOUR_SERVER_IP -Port 5432

# Connect with psql
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -h YOUR_SERVER_IP -U ponder -d mail_box_indexer
```

**From Docker Container**:

```bash
# Test connection from mail_box_indexer container
docker exec -it mail_box_indexer sh -c 'psql $DATABASE_URL -c "SELECT version();"'
```

## 📊 Configuration Details

### postgresql.conf Settings

**Memory Settings** (tuned for 96GB available RAM):
- `shared_buffers = 24GB` - 25% of available RAM
- `effective_cache_size = 72GB` - 75% of available RAM
- `work_mem = 64MB` - Per-operation memory (for 500 connections)
- `maintenance_work_mem = 4GB` - For VACUUM, CREATE INDEX on large tables

**Performance Settings** (optimized for RAID6 SSD):
- `max_connections = 500` - High-capacity concurrent connections
- `random_page_cost = 1.0` - Optimized for SSD (eliminates seek time penalty)
- `effective_io_concurrency = 300` - High for RAID6 SSD (excellent parallel I/O)
- `checkpoint_flush_after = 2MB` - Larger batches for SSD efficiency
- `log_temp_files = 100MB` - Higher threshold (SSDs handle temp files efficiently)
- `max_parallel_workers_per_gather = 8` - Parallel query workers (increased for multi-core)
- `max_worker_processes = 16` - Total background processes
- `max_parallel_workers = 16` - Total parallel workers

**WAL Settings** (for 10TB storage):
- `max_wal_size = 16GB` - Maximum WAL size between checkpoints
- `min_wal_size = 4GB` - Minimum WAL size to keep
- `wal_buffers = 64MB` - WAL buffer size
- `temp_file_limit = 50GB` - Per-session temp file limit

**Logging** (minimized for disk space):
- `log_min_duration_statement = 5000` - Only log queries slower than 5 seconds
- `log_connections = off` - Connection logging disabled (saves significant disk space)
- `log_disconnections = off` - Disconnection logging disabled
- `log_checkpoints = off` - Checkpoint logging disabled
- `log_truncate_on_rotation = on` - Overwrites old logs daily (keeps only 1 day)
- Log retention: 1 day only (rotates and overwrites daily)

**Timeouts**:
- `statement_timeout = 30s` - Prevent runaway queries
- `idle_in_transaction_session_timeout = 60s` - Clean up stale connections

**Extensions**:
- `shared_preload_libraries = 'pg_stat_statements'` - Query performance monitoring

### pg_hba.conf Authentication

**Local Connections**:
- Unix sockets (Linux/Mac): `scram-sha-256`
- TCP/IP localhost (127.0.0.1): `scram-sha-256`

**Docker Connections**:
- Network range: 172.17.0.0/16
- User: `ponder`
- Database: `mail_box_indexer`
- Method: `scram-sha-256`

**Remote Connections** (customize these!):
- **IMPORTANT**: Replace placeholder IPs with actual IPs
- Use specific IPs (e.g., 192.168.1.100/32) not 0.0.0.0/0
- Consider using `hostssl` for SSL-required connections
- See inline comments in pg_hba.conf for examples

### init_database.sql

Creates:
- Database: `mail_box_indexer` (UTF8, C collation)
- User: `ponder` (with default password 'password')
- Extensions: pgcrypto, uuid-ossp, pg_trgm, btree_gin, btree_gist, pg_stat_statements
- Permissions: Full privileges for ponder user on mail_box_indexer database

**CRITICAL**: Change the default password immediately after running!

### backup_database.ps1

Features:
- Custom format compressed backups (pg_dump -F c)
- Automatic backup cleanup (30-day retention)
- **Automatic log cleanup (7-day retention)** - Minimizes disk usage
- Database size reporting
- Duration tracking
- Detailed logging with automatic cleanup
- Error handling with exit codes

Backup location: `C:\PostgreSQL\backups\`
Backup filename format: `mail_box_indexer_YYYY-MM-DD_HHmmss.backup`

**Disk Space Management**:
- Backup logs automatically cleaned after 7 days
- Only essential backup logs retained
- Minimizes disk usage for maximum user account storage

## 🔐 Security Checklist

- [ ] Changed default ponder password from 'password'
- [ ] Edited pg_hba.conf with actual IP addresses (removed 0.0.0.0/0)
- [ ] Configured firewall to allow only necessary IPs
- [ ] Set up .pgpass or PGPASSWORD for backups
- [ ] Tested remote connections work
- [ ] Verified backups run successfully
- [ ] Scheduled automated backups
- [ ] Enabled SSL/TLS for remote connections (optional but recommended)
- [ ] Set strong password requirements in postgresql.conf
- [ ] Reviewed log files for unauthorized access attempts

## 🧪 Testing and Verification

### Check PostgreSQL is Running

```powershell
# Service status
Get-Service postgresql-x64-17

# Listening ports
netstat -an | Select-String ":5432"

# Should show:
# TCP    0.0.0.0:5432           0.0.0.0:0              LISTENING
# TCP    [::]:5432              [::]:0                 LISTENING
```

### Verify Configuration Loaded

```powershell
# Connect to database
cd "C:\Program Files\PostgreSQL\17\bin"
.\psql.exe -U postgres -d mail_box_indexer

# Inside psql, check settings
SHOW shared_buffers;          # Should be 2GB
SHOW max_connections;         # Should be 200
SHOW listen_addresses;        # Should be *
SHOW shared_preload_libraries; # Should include pg_stat_statements
\q
```

### Test User Permissions

```powershell
# Connect as ponder user
.\psql.exe -U ponder -d mail_box_indexer

# Inside psql, test permissions
CREATE TABLE test_table (id serial primary key, data text);
INSERT INTO test_table (data) VALUES ('test');
SELECT * FROM test_table;
DROP TABLE test_table;
\q
```

### Verify Extensions

```powershell
# Connect to database
.\psql.exe -U postgres -d mail_box_indexer -c "\dx"

# Should show:
# - plpgsql
# - pg_stat_statements
# - pgcrypto
# - uuid-ossp
# - pg_trgm
# - btree_gin
# - btree_gist
```

### Monitor Query Performance

```powershell
# Connect to database
.\psql.exe -U ponder -d mail_box_indexer

# Inside psql, view slow queries
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

# View current connections
SELECT * FROM pg_stat_activity;
\q
```

## 🐛 Troubleshooting

### PostgreSQL Won't Start

```powershell
# Check Windows Event Viewer
Get-EventLog -LogName Application -Source PostgreSQL -Newest 20

# Check PostgreSQL logs
Get-Content "C:\PostgreSQL\data\log\postgresql-*.log" -Tail 100

# Common issues:
# 1. Port 5432 already in use
# 2. Data directory permissions
# 3. Syntax error in postgresql.conf or pg_hba.conf
```

### Remote Connection Refused

```powershell
# Verify PostgreSQL is listening on all interfaces
netstat -an | Select-String ":5432"
# Should show 0.0.0.0:5432, not 127.0.0.1:5432

# Verify firewall rule exists
Get-NetFirewallRule -DisplayName "PostgreSQL Mail Box Indexer"

# Verify pg_hba.conf has entry for remote IP
Get-Content "C:\PostgreSQL\data\pg_hba.conf" | Select-String "ponder"
```

### Authentication Failed

```powershell
# Check pg_hba.conf authentication method
Get-Content "C:\PostgreSQL\data\pg_hba.conf" | Select-String "scram-sha-256"

# Verify user exists and password is correct
.\psql.exe -U postgres -c "\du ponder"

# Reset password if needed
.\psql.exe -U postgres -c "ALTER USER ponder WITH PASSWORD 'new-password';"
```

### Backup Script Fails

```powershell
# Run backup script manually to see errors
cd "C:\PostgreSQL"
.\backup_database.ps1

# Check error log
Get-Content "C:\PostgreSQL\backups\backup_log_*.txt" -Tail 50

# Common issues:
# 1. Password not configured (.pgpass or PGPASSWORD)
# 2. pg_dump.exe not in PATH
# 3. Insufficient disk space
# 4. PostgreSQL service not running
```

### Connection String Issues

For Docker containers accessing Windows PostgreSQL:

```bash
# Use host.docker.internal on Windows/Mac
DATABASE_URL=postgresql://ponder:password@host.docker.internal:5432/mail_box_indexer

# Or use Windows host IP (find with ipconfig)
DATABASE_URL=postgresql://ponder:password@192.168.1.100:5432/mail_box_indexer
```

Test from inside container:

```bash
docker exec -it mail_box_indexer sh
apk add postgresql-client
psql postgresql://ponder:password@host.docker.internal:5432/mail_box_indexer
```

## 📚 Additional Resources

### PostgreSQL Documentation
- [PostgreSQL 17 Documentation](https://www.postgresql.org/docs/17/)
- [Server Configuration](https://www.postgresql.org/docs/17/runtime-config.html)
- [Client Authentication](https://www.postgresql.org/docs/17/auth-pg-hba-conf.html)
- [Backup and Restore](https://www.postgresql.org/docs/17/backup.html)

### Performance Tuning
- [PgTune](https://pgtune.leopard.in.ua/) - Configuration calculator
- [Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)

### Monitoring
- [pg_stat_statements](https://www.postgresql.org/docs/17/pgstatstatements.html)
- [pgAdmin 4](https://www.pgadmin.org/) - GUI administration tool

### Security
- [Security Best Practices](https://www.postgresql.org/docs/17/ssl-tcp.html)
- [Authentication Methods](https://www.postgresql.org/docs/17/auth-methods.html)

## 🔄 Maintenance Tasks

### Daily
- Automated backups (via scheduled task)

### Weekly
- Review backup logs for failures
- Check disk space for backups and data
- Review slow query log

### Monthly
- Rotate old backups manually if needed
- Review pg_stat_statements for optimization opportunities
- Update passwords per security policy
- Review and update pg_hba.conf access rules

### Quarterly
- Vacuum database manually: `VACUUM ANALYZE;`
- Review and update postgresql.conf settings
- Test backup restoration process
- Security audit of access logs

## 📝 Connection Strings

### Local Development (Windows)
```
postgresql://ponder:password@localhost:5432/mail_box_indexer
```

### Docker on Windows Host
```
postgresql://ponder:password@host.docker.internal:5432/mail_box_indexer
```

### Remote Access
```
postgresql://ponder:password@YOUR_SERVER_IP:5432/mail_box_indexer
```

### SSL/TLS Connection (if configured)
```
postgresql://ponder:password@YOUR_SERVER_IP:5432/mail_box_indexer?sslmode=require
```

## 🎯 Next Steps

1. ✅ Deploy configuration files to PostgreSQL data directory
2. ✅ Restart PostgreSQL service
3. ✅ Run init_database.sql to create database and user
4. ✅ Change default ponder password
5. ✅ Test local connection
6. ✅ Configure firewall for remote access (if needed)
7. ✅ Test remote connection (if needed)
8. ✅ Set up automated backups
9. ✅ Test backup script manually
10. ✅ Schedule daily backups with Task Scheduler

## 💡 Tips

- **Memory Tuning**: If you have more than 8GB RAM, increase `shared_buffers` and `effective_cache_size` proportionally
- **Connection Pooling**: For high-traffic applications, consider using PgBouncer
- **SSL/TLS**: For production, enable SSL in postgresql.conf and use `hostssl` in pg_hba.conf
- **Monitoring**: Install pgAdmin 4 for GUI-based monitoring and administration
- **Backup Testing**: Regularly test backup restoration to ensure backups are valid
- **Documentation**: Keep a log of configuration changes and why they were made

## 🆘 Support

If you encounter issues:

1. Check PostgreSQL logs: `C:\PostgreSQL\data\log\postgresql-*.log`
2. Check Windows Event Viewer: Application logs with source "PostgreSQL"
3. Verify configuration syntax: `postgres.exe -D "C:\PostgreSQL\data" --check`
4. Review this README's troubleshooting section
5. Consult official PostgreSQL documentation
6. Check the mail_box_indexer application logs for connection errors

---

**Last Updated**: 2025-10-05
**PostgreSQL Version**: 17
**Target OS**: Windows Server
**Maintainer**: WildDuck Deployment
