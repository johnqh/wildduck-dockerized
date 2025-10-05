# PostgreSQL Backup Script
# Mail Box Indexer Database Backup
#
# This script creates a compressed backup of the mail_box_indexer database
# Schedule this with Windows Task Scheduler for automatic backups

# Configuration
$PostgreSQLBin = "C:\Program Files\PostgreSQL\17\bin"
$BackupDir = "C:\PostgreSQL\backups"
$Database = "mail_box_indexer"
$Username = "ponder"
$RetentionDays = 30  # Keep backups for 30 days

# Create timestamp for filename
$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$BackupFile = Join-Path $BackupDir "$Database`_$Timestamp.backup"
$LogFile = Join-Path $BackupDir "backup_log_$Timestamp.txt"

# Create backup directory if it doesn't exist
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Host "Created backup directory: $BackupDir" -ForegroundColor Green
}

# Start logging
$LogContent = @"
================================================================================
PostgreSQL Backup Log
================================================================================
Database: $Database
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Backup File: $BackupFile
================================================================================

"@

Write-Host $LogContent
Add-Content -Path $LogFile -Value $LogContent

try {
    # Check if PostgreSQL is running
    $Service = Get-Service -Name "postgresql-x64-17" -ErrorAction Stop
    if ($Service.Status -ne "Running") {
        throw "PostgreSQL service is not running!"
    }

    Write-Host "PostgreSQL service is running" -ForegroundColor Green
    Add-Content -Path $LogFile -Value "PostgreSQL service status: Running"

    # Get database size before backup
    $SizeQuery = "SELECT pg_size_pretty(pg_database_size('$Database'));"
    $DbSize = & "$PostgreSQLBin\psql.exe" -U $Username -d $Database -t -c $SizeQuery
    $DbSize = $DbSize.Trim()

    Write-Host "Database size: $DbSize" -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value "Database size: $DbSize"

    # Perform backup using pg_dump
    # -F c = custom format (compressed)
    # -b = include large objects
    # -v = verbose
    # -f = output file
    Write-Host "`nStarting backup..." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "`nStarting backup process..."

    $StartTime = Get-Date

    $BackupProcess = Start-Process -FilePath "$PostgreSQLBin\pg_dump.exe" `
        -ArgumentList "-U", $Username, "-F", "c", "-b", "-v", "-f", $BackupFile, $Database `
        -Wait -PassThru -NoNewWindow -RedirectStandardError "$BackupDir\error_$Timestamp.txt"

    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime

    if ($BackupProcess.ExitCode -eq 0) {
        # Backup successful
        $BackupSize = (Get-Item $BackupFile).Length
        $BackupSizeMB = [math]::Round($BackupSize / 1MB, 2)

        $SuccessMessage = @"

================================================================================
BACKUP SUCCESSFUL
================================================================================
Backup file: $BackupFile
Backup size: $BackupSizeMB MB
Duration: $($Duration.ToString('hh\:mm\:ss'))
Compression: Custom format (compressed)

"@

        Write-Host $SuccessMessage -ForegroundColor Green
        Add-Content -Path $LogFile -Value $SuccessMessage

        # Clean up old backups
        Write-Host "Cleaning up old backups (older than $RetentionDays days)..." -ForegroundColor Yellow
        Add-Content -Path $LogFile -Value "Cleaning up backups older than $RetentionDays days..."

        $OldBackups = Get-ChildItem -Path $BackupDir -Filter "$Database`_*.backup" |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

        if ($OldBackups.Count -gt 0) {
            foreach ($OldBackup in $OldBackups) {
                Remove-Item $OldBackup.FullName -Force
                Write-Host "Removed old backup: $($OldBackup.Name)" -ForegroundColor Gray
                Add-Content -Path $LogFile -Value "Removed: $($OldBackup.Name)"
            }
            Write-Host "Removed $($OldBackups.Count) old backup(s)" -ForegroundColor Green
        } else {
            Write-Host "No old backups to remove" -ForegroundColor Gray
            Add-Content -Path $LogFile -Value "No old backups to remove"
        }

        # List current backups
        $CurrentBackups = Get-ChildItem -Path $BackupDir -Filter "$Database`_*.backup" |
            Sort-Object LastWriteTime -Descending

        Write-Host "`nCurrent backups:" -ForegroundColor Cyan
        Add-Content -Path $LogFile -Value "`nCurrent backups:"

        foreach ($Backup in $CurrentBackups) {
            $BackupInfo = "$($Backup.Name) - $([math]::Round($Backup.Length / 1MB, 2)) MB - $($Backup.LastWriteTime)"
            Write-Host "  $BackupInfo" -ForegroundColor Gray
            Add-Content -Path $LogFile -Value "  $BackupInfo"
        }

        Add-Content -Path $LogFile -Value "`n================================================================================`n"

        # Return success
        exit 0

    } else {
        # Backup failed
        $ErrorContent = Get-Content "$BackupDir\error_$Timestamp.txt" -Raw

        $FailureMessage = @"

================================================================================
BACKUP FAILED
================================================================================
Exit code: $($BackupProcess.ExitCode)
Error details:
$ErrorContent

"@

        Write-Host $FailureMessage -ForegroundColor Red
        Add-Content -Path $LogFile -Value $FailureMessage
        Add-Content -Path $LogFile -Value "`n================================================================================`n"

        # Send email alert (configure SMTP settings)
        # Uncomment and configure if you want email alerts
        # $EmailParams = @{
        #     From = "postgres@yourdomain.com"
        #     To = "admin@yourdomain.com"
        #     Subject = "PostgreSQL Backup Failed - $Database"
        #     Body = $FailureMessage
        #     SmtpServer = "smtp.yourdomain.com"
        # }
        # Send-MailMessage @EmailParams

        # Return failure
        exit 1
    }

} catch {
    $ErrorMessage = @"

================================================================================
BACKUP ERROR
================================================================================
Error: $($_.Exception.Message)
Stack trace:
$($_.ScriptStackTrace)

"@

    Write-Host $ErrorMessage -ForegroundColor Red
    Add-Content -Path $LogFile -Value $ErrorMessage
    Add-Content -Path $LogFile -Value "`n================================================================================`n"

    # Return error
    exit 1

} finally {
    # Clean up temporary error file if backup succeeded
    $ErrorFile = "$BackupDir\error_$Timestamp.txt"
    if (Test-Path $ErrorFile) {
        $ErrorContent = Get-Content $ErrorFile -Raw
        if ([string]::IsNullOrWhiteSpace($ErrorContent)) {
            Remove-Item $ErrorFile -Force
        }
    }

    # Clean up old log files (keep only last 7 days)
    # This minimizes disk usage for logs
    Write-Host "`nCleaning up old log files..." -ForegroundColor Yellow
    try {
        $OldLogs = Get-ChildItem -Path $BackupDir -Filter "backup_log_*.txt" |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }

        if ($OldLogs.Count -gt 0) {
            foreach ($OldLog in $OldLogs) {
                Remove-Item $OldLog.FullName -Force
            }
            Write-Host "Removed $($OldLogs.Count) old log file(s)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning: Could not clean up old logs: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Backup PostgreSQL database with rotation

.DESCRIPTION
    This script creates a compressed backup of the mail_box_indexer database
    and automatically removes old backups based on retention policy.

.PARAMETER PostgreSQLBin
    Path to PostgreSQL bin directory

.PARAMETER BackupDir
    Directory to store backups

.PARAMETER Database
    Name of database to backup

.PARAMETER Username
    PostgreSQL username for backup

.PARAMETER RetentionDays
    Number of days to keep old backups

.EXAMPLE
    .\backup_database.ps1

    Runs backup with default settings

.EXAMPLE
    Schedule with Task Scheduler:
    - Action: Start a program
    - Program: powershell.exe
    - Arguments: -ExecutionPolicy Bypass -File "C:\path\to\backup_database.ps1"
    - Schedule: Daily at 2:00 AM

.NOTES
    Author: WildDuck Deployment
    Requires: PostgreSQL 17
    Password: Configure pgpass file or set PGPASSWORD environment variable
#>
