# MongoDB Backup Script
# WildDuck Mail Server Database Backup
#
# This script creates a compressed backup of MongoDB databases
# Schedule this with Windows Task Scheduler for automatic backups
#
# Usage:
#   .\backup_database.ps1
#   .\backup_database.ps1 -Database "wildduck" -RetentionDays 7
#   .\backup_database.ps1 -FullBackup  # Backup all databases

param(
    [string]$Database = "wildduck",
    [int]$RetentionDays = 30,
    [switch]$FullBackup,
    [switch]$Help
)

# Show help
if ($Help) {
    Write-Host @"
MongoDB Backup Script for WildDuck Mail Server

USAGE:
    .\backup_database.ps1 [options]

OPTIONS:
    -Database <name>        Database to backup (default: wildduck)
    -RetentionDays <days>   Keep backups for N days (default: 30)
    -FullBackup            Backup all databases instead of specific one
    -Help                  Show this help message

EXAMPLES:
    # Backup wildduck database with default settings
    .\backup_database.ps1

    # Backup specific database with 7-day retention
    .\backup_database.ps1 -Database "zone-mta" -RetentionDays 7

    # Backup all databases
    .\backup_database.ps1 -FullBackup

    # Schedule with Task Scheduler
    Register-ScheduledTask -TaskName "MongoDB-Backup" ``
        -Action (New-ScheduledTaskAction -Execute "powershell.exe" ``
            -Argument "-ExecutionPolicy Bypass -File C:\MongoDB\backup_database.ps1") ``
        -Trigger (New-ScheduledTaskTrigger -Daily -At 2am) ``
        -User "SYSTEM"

"@
    exit 0
}

# ==============================================================================
# Configuration
# ==============================================================================

$MongoDBBin = "C:\Program Files\MongoDB\Server\7.0\bin"
$BackupDir = "C:\MongoDB\backups"
$MongoHost = "localhost"
$MongoPort = "27017"
$MongoUser = "admin"  # Use admin user for backups
# Note: Set MONGO_PASSWORD environment variable or configure .mongorc.js for auth

# ==============================================================================
# Initialize
# ==============================================================================

# Create timestamp for filename
$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$BackupName = if ($FullBackup) { "full" } else { $Database }
$BackupPath = Join-Path $BackupDir "$BackupName`_$Timestamp"
$LogFile = Join-Path $BackupDir "backup_log_$Timestamp.txt"

# Create backup directory if it doesn't exist
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Host "Created backup directory: $BackupDir" -ForegroundColor Green
}

# ==============================================================================
# Logging Function
# ==============================================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $LogMessage -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $LogMessage
}

# ==============================================================================
# Start Logging
# ==============================================================================

$LogHeader = @"
================================================================================
MongoDB Backup Log
================================================================================
Backup Type: $(if ($FullBackup) { "Full (all databases)" } else { "Single database: $Database" })
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Backup Path: $BackupPath
Retention: $RetentionDays days
================================================================================

"@

Write-Host $LogHeader
Add-Content -Path $LogFile -Value $LogHeader

# ==============================================================================
# Pre-Backup Checks
# ==============================================================================

try {
    Write-Log "Starting pre-backup checks..." "Yellow"

    # Check if MongoDB service is running
    $Service = Get-Service -Name "MongoDB" -ErrorAction Stop
    if ($Service.Status -ne "Running") {
        throw "MongoDB service is not running!"
    }
    Write-Log "✓ MongoDB service is running" "Green"

    # Check if mongodump exists
    $MongoDumpPath = Join-Path $MongoDBBin "mongodump.exe"
    if (-not (Test-Path $MongoDumpPath)) {
        throw "mongodump.exe not found at: $MongoDumpPath"
    }
    Write-Log "✓ mongodump.exe found" "Green"

    # Test MongoDB connection
    $MongoEvalPath = Join-Path $MongoDBBin "mongosh.exe"
    if (Test-Path $MongoEvalPath) {
        Write-Log "Testing MongoDB connection..." "Cyan"

        # Build connection string
        $ConnectTest = if ($env:MONGO_PASSWORD) {
            & $MongoEvalPath --host $MongoHost --port $MongoPort `
                --username $MongoUser --password $env:MONGO_PASSWORD `
                --authenticationDatabase admin --quiet --eval "db.adminCommand('ping')"
        } else {
            & $MongoEvalPath --host $MongoHost --port $MongoPort --quiet --eval "db.adminCommand('ping')"
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ MongoDB connection successful" "Green"
        } else {
            Write-Log "⚠ MongoDB connection test inconclusive, proceeding anyway..." "Yellow"
        }
    }

    # Get database size before backup
    if (-not $FullBackup) {
        Write-Log "Getting database size..." "Cyan"

        $DbStatsCmd = "db.stats()"
        $DbStats = if ($env:MONGO_PASSWORD) {
            & $MongoEvalPath --host $MongoHost --port $MongoPort `
                --username $MongoUser --password $env:MONGO_PASSWORD `
                --authenticationDatabase admin --quiet $Database --eval $DbStatsCmd 2>&1
        } else {
            & $MongoEvalPath --host $MongoHost --port $MongoPort --quiet $Database --eval $DbStatsCmd 2>&1
        }

        if ($DbStats -match "dataSize.*?(\d+)") {
            $DataSize = [math]::Round([int64]$Matches[1] / 1MB, 2)
            Write-Log "Database size: $DataSize MB" "Cyan"
        }
    }

} catch {
    Write-Log "✗ Pre-backup check failed: $($_.Exception.Message)" "Red"
    Write-Log "Backup aborted" "Red"
    exit 1
}

Write-Log "" "White"

# ==============================================================================
# Perform Backup
# ==============================================================================

try {
    Write-Log "Starting backup process..." "Yellow"

    $StartTime = Get-Date

    # Build mongodump command arguments
    $MongoDumpArgs = @(
        "--host", "$MongoHost`:$MongoPort",
        "--out", $BackupPath,
        "--gzip"  # Compress backup files
    )

    # Add authentication if password is set
    if ($env:MONGO_PASSWORD) {
        $MongoDumpArgs += "--username", $MongoUser
        $MongoDumpArgs += "--password", $env:MONGO_PASSWORD
        $MongoDumpArgs += "--authenticationDatabase", "admin"
    }

    # Add database parameter for single database backup
    if (-not $FullBackup) {
        $MongoDumpArgs += "--db", $Database
    }

    # Add oplog for point-in-time backup (only for full backups)
    if ($FullBackup) {
        $MongoDumpArgs += "--oplog"
        Write-Log "Including oplog for point-in-time recovery" "Cyan"
    }

    Write-Log "Running: mongodump $($MongoDumpArgs -join ' ')" "Gray"
    Write-Log "" "White"

    # Execute mongodump
    $BackupProcess = Start-Process -FilePath $MongoDumpPath `
        -ArgumentList $MongoDumpArgs `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput "$BackupDir\stdout_$Timestamp.txt" `
        -RedirectStandardError "$BackupDir\stderr_$Timestamp.txt"

    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime

    if ($BackupProcess.ExitCode -eq 0) {
        # Backup successful
        Write-Log "" "White"
        Write-Log "=================================================================================" "Green"
        Write-Log "BACKUP SUCCESSFUL" "Green"
        Write-Log "=================================================================================" "Green"

        # Calculate backup size
        $BackupSize = (Get-ChildItem -Path $BackupPath -Recurse | Measure-Object -Property Length -Sum).Sum
        $BackupSizeMB = [math]::Round($BackupSize / 1MB, 2)

        Write-Log "Backup path: $BackupPath" "White"
        Write-Log "Backup size: $BackupSizeMB MB" "White"
        Write-Log "Duration: $($Duration.ToString('hh\:mm\:ss'))" "White"
        Write-Log "Compression: gzip" "White"

        # Archive backup directory into a single file (optional)
        Write-Log "" "White"
        Write-Log "Creating archive..." "Yellow"

        $ArchivePath = "$BackupPath.zip"
        Compress-Archive -Path $BackupPath -DestinationPath $ArchivePath -CompressionLevel Optimal

        # Remove uncompressed backup directory
        Remove-Item -Path $BackupPath -Recurse -Force

        $ArchiveSize = (Get-Item $ArchivePath).Length
        $ArchiveSizeMB = [math]::Round($ArchiveSize / 1MB, 2)

        Write-Log "✓ Created archive: $ArchivePath" "Green"
        Write-Log "  Archive size: $ArchiveSizeMB MB" "White"

        # Clean up stdout/stderr if empty
        $StdoutFile = "$BackupDir\stdout_$Timestamp.txt"
        $StderrFile = "$BackupDir\stderr_$Timestamp.txt"

        if (Test-Path $StdoutFile) {
            if ((Get-Item $StdoutFile).Length -eq 0) {
                Remove-Item $StdoutFile -Force
            }
        }
        if (Test-Path $StderrFile) {
            if ((Get-Item $StderrFile).Length -eq 0) {
                Remove-Item $StderrFile -Force
            }
        }

        # Clean up old log files (keep only last 7 days)
        # This minimizes disk usage for logs
        Write-Log "" "White"
        Write-Log "Cleaning up old log files..." "Yellow"
        try {
            $OldLogs = Get-ChildItem -Path $BackupDir -Filter "backup_log_*.txt" |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }

            if ($OldLogs.Count -gt 0) {
                foreach ($OldLog in $OldLogs) {
                    Remove-Item $OldLog.FullName -Force
                    Write-Log "Removed old log: $($OldLog.Name)" "Gray"
                }
                Write-Log "✓ Removed $($OldLogs.Count) old log file(s)" "Green"
            }
        } catch {
            Write-Log "⚠ Warning: Could not clean up old logs: $($_.Exception.Message)" "Yellow"
        }

    } else {
        # Backup failed
        Write-Log "" "White"
        Write-Log "=================================================================================" "Red"
        Write-Log "BACKUP FAILED" "Red"
        Write-Log "=================================================================================" "Red"

        $ErrorContent = Get-Content "$BackupDir\stderr_$Timestamp.txt" -Raw -ErrorAction SilentlyContinue

        Write-Log "Exit code: $($BackupProcess.ExitCode)" "Red"
        Write-Log "Error details:" "Red"
        Write-Log $ErrorContent "Red"

        exit 1
    }

} catch {
    Write-Log "" "White"
    Write-Log "=================================================================================" "Red"
    Write-Log "BACKUP ERROR" "Red"
    Write-Log "=================================================================================" "Red"
    Write-Log "Error: $($_.Exception.Message)" "Red"
    Write-Log "Stack trace:" "Red"
    Write-Log "$($_.ScriptStackTrace)" "Red"
    exit 1
}

# ==============================================================================
# Clean Up Old Backups
# ==============================================================================

Write-Log "" "White"
Write-Log "Cleaning up old backups (older than $RetentionDays days)..." "Yellow"

try {
    $OldBackups = Get-ChildItem -Path $BackupDir -Filter "$BackupName`_*.zip" |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

    if ($OldBackups.Count -gt 0) {
        foreach ($OldBackup in $OldBackups) {
            Remove-Item $OldBackup.FullName -Force
            Write-Log "Removed old backup: $($OldBackup.Name)" "Gray"
        }
        Write-Log "✓ Removed $($OldBackups.Count) old backup(s)" "Green"
    } else {
        Write-Log "No old backups to remove" "Gray"
    }

} catch {
    Write-Log "⚠ Error during cleanup: $($_.Exception.Message)" "Yellow"
}

# ==============================================================================
# List Current Backups
# ==============================================================================

Write-Log "" "White"
Write-Log "Current backups:" "Cyan"

try {
    $CurrentBackups = Get-ChildItem -Path $BackupDir -Filter "$BackupName`_*.zip" |
        Sort-Object LastWriteTime -Descending

    if ($CurrentBackups.Count -gt 0) {
        foreach ($Backup in $CurrentBackups) {
            $BackupInfo = "{0} - {1:N2} MB - {2}" -f $Backup.Name, ($Backup.Length / 1MB), $Backup.LastWriteTime
            Write-Log "  $BackupInfo" "Gray"
        }
        Write-Log "" "White"
        Write-Log "Total backups: $($CurrentBackups.Count)" "Cyan"

        $TotalSize = ($CurrentBackups | Measure-Object -Property Length -Sum).Sum
        $TotalSizeMB = [math]::Round($TotalSize / 1MB, 2)
        $TotalSizeGB = [math]::Round($TotalSize / 1GB, 2)

        Write-Log "Total size: $TotalSizeMB MB ($TotalSizeGB GB)" "Cyan"
    } else {
        Write-Log "  No backups found" "Gray"
    }

} catch {
    Write-Log "⚠ Error listing backups: $($_.Exception.Message)" "Yellow"
}

# ==============================================================================
# Summary
# ==============================================================================

Write-Log "" "White"
Write-Log "=================================================================================" "Green"
Write-Log "Backup completed successfully!" "Green"
Write-Log "=================================================================================" "Green"
Write-Log "" "White"

# Return success
exit 0

<#
.SYNOPSIS
    Backup MongoDB databases with compression and rotation

.DESCRIPTION
    This script creates compressed backups of MongoDB databases using mongodump.
    Supports single database or full backup of all databases.
    Automatically removes old backups based on retention policy.
    Archives backups into .zip files for efficient storage.

.PARAMETER Database
    Name of database to backup (default: wildduck)

.PARAMETER RetentionDays
    Number of days to keep old backups (default: 30)

.PARAMETER FullBackup
    Backup all databases instead of specific one (includes oplog)

.PARAMETER Help
    Show help message

.EXAMPLE
    .\backup_database.ps1
    Backs up the wildduck database with default settings

.EXAMPLE
    .\backup_database.ps1 -Database "zone-mta" -RetentionDays 7
    Backs up zone-mta database with 7-day retention

.EXAMPLE
    .\backup_database.ps1 -FullBackup
    Backs up all databases with oplog for point-in-time recovery

.EXAMPLE
    # Schedule with Task Scheduler (run as Administrator)
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -File C:\MongoDB\backup_database.ps1"
    $Trigger = New-ScheduledTaskTrigger -Daily -At 2am
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

    Register-ScheduledTask -TaskName "MongoDB-WildDuck-Backup" `
        -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings `
        -Description "Daily backup of WildDuck MongoDB database"

.NOTES
    Author: WildDuck Deployment
    Requires: MongoDB 7.0+ with mongodump
    Password: Set MONGO_PASSWORD environment variable or configure .mongorc.js

    To set password for current session:
        $env:MONGO_PASSWORD = "your-admin-password"

    To set password permanently:
        [System.Environment]::SetEnvironmentVariable('MONGO_PASSWORD', 'your-admin-password', 'User')

    To restore a backup:
        mongorestore --host localhost --port 27017 --gzip --archive=backup.zip

        # Or extract and restore:
        Expand-Archive backup.zip -DestinationPath C:\Temp\restore
        mongorestore --host localhost --port 27017 --gzip C:\Temp\restore
#>
