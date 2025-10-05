# MongoDB Log Cleanup Script
# Automatically clean up old MongoDB log files to save disk space
#
# This script should be scheduled to run weekly via Task Scheduler
# It keeps only the most recent MongoDB log files
#
# Usage:
#   .\cleanup_logs.ps1
#   .\cleanup_logs.ps1 -RetentionDays 7 -LogDirectory "C:\MongoDB\log"

param(
    [int]$RetentionDays = 7,
    [string]$LogDirectory = "C:\MongoDB\log",
    [switch]$Help
)

if ($Help) {
    Write-Host @"
MongoDB Log Cleanup Script

USAGE:
    .\cleanup_logs.ps1 [options]

OPTIONS:
    -RetentionDays <days>    Keep logs for N days (default: 7)
    -LogDirectory <path>     MongoDB log directory (default: C:\MongoDB\log)
    -Help                    Show this help message

EXAMPLES:
    # Clean up logs older than 7 days
    .\cleanup_logs.ps1

    # Keep only 3 days of logs
    .\cleanup_logs.ps1 -RetentionDays 3

    # Custom log directory
    .\cleanup_logs.ps1 -LogDirectory "D:\MongoDB\log"

    # Schedule with Task Scheduler (run as Administrator)
    Register-ScheduledTask -TaskName "MongoDB-Log-Cleanup" ``
        -Action (New-ScheduledTaskAction -Execute "powershell.exe" ``
            -Argument "-ExecutionPolicy Bypass -File C:\MongoDB\cleanup_logs.ps1") ``
        -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am) ``
        -User "SYSTEM"

"@
    exit 0
}

# ==============================================================================
# Main Script
# ==============================================================================

Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "MongoDB Log Cleanup" -ForegroundColor Cyan
Write-Host "=================================================================================" -ForegroundColor Cyan
Write-Host "Log Directory: $LogDirectory"
Write-Host "Retention: $RetentionDays days"
Write-Host "Cutoff Date: $((Get-Date).AddDays(-$RetentionDays).ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ""

# Check if log directory exists
if (-not (Test-Path $LogDirectory)) {
    Write-Host "Error: Log directory does not exist: $LogDirectory" -ForegroundColor Red
    exit 1
}

# Find old log files
try {
    Write-Host "Scanning for old log files..." -ForegroundColor Yellow

    # MongoDB creates rotated logs with pattern: mongod.log.YYYY-MM-DDTHH-mm-ss
    $OldLogs = Get-ChildItem -Path $LogDirectory -Filter "mongod.log.*" |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

    if ($OldLogs.Count -eq 0) {
        Write-Host "No old log files found to clean up." -ForegroundColor Green
        Write-Host ""

        # Show current log files
        Write-Host "Current log files:" -ForegroundColor Cyan
        $CurrentLogs = Get-ChildItem -Path $LogDirectory -Filter "mongod.log*" |
            Sort-Object LastWriteTime -Descending

        $TotalSize = 0
        foreach ($Log in $CurrentLogs) {
            $SizeMB = [math]::Round($Log.Length / 1MB, 2)
            $TotalSize += $Log.Length
            Write-Host "  $($Log.Name) - $SizeMB MB - $($Log.LastWriteTime)" -ForegroundColor Gray
        }

        $TotalSizeMB = [math]::Round($TotalSize / 1MB, 2)
        Write-Host ""
        Write-Host "Total log size: $TotalSizeMB MB" -ForegroundColor Cyan

        exit 0
    }

    # Calculate total size to be freed
    $TotalSize = ($OldLogs | Measure-Object -Property Length -Sum).Sum
    $TotalSizeMB = [math]::Round($TotalSize / 1MB, 2)

    Write-Host "Found $($OldLogs.Count) old log file(s) - Total size: $TotalSizeMB MB" -ForegroundColor Yellow
    Write-Host ""

    # Delete old log files
    Write-Host "Deleting old log files..." -ForegroundColor Yellow
    $DeletedCount = 0
    $DeletedSize = 0

    foreach ($Log in $OldLogs) {
        try {
            $LogSizeMB = [math]::Round($Log.Length / 1MB, 2)
            Remove-Item $Log.FullName -Force
            Write-Host "  ✓ Deleted: $($Log.Name) ($LogSizeMB MB)" -ForegroundColor Gray
            $DeletedCount++
            $DeletedSize += $Log.Length
        } catch {
            Write-Host "  ✗ Failed to delete: $($Log.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $DeletedSizeMB = [math]::Round($DeletedSize / 1MB, 2)

    Write-Host ""
    Write-Host "=================================================================================" -ForegroundColor Green
    Write-Host "Cleanup completed successfully!" -ForegroundColor Green
    Write-Host "=================================================================================" -ForegroundColor Green
    Write-Host "Files deleted: $DeletedCount" -ForegroundColor White
    Write-Host "Disk space freed: $DeletedSizeMB MB" -ForegroundColor White
    Write-Host ""

    # Show remaining log files
    Write-Host "Remaining log files:" -ForegroundColor Cyan
    $RemainingLogs = Get-ChildItem -Path $LogDirectory -Filter "mongod.log*" |
        Sort-Object LastWriteTime -Descending

    $RemainingSize = 0
    foreach ($Log in $RemainingLogs) {
        $SizeMB = [math]::Round($Log.Length / 1MB, 2)
        $RemainingSize += $Log.Length
        Write-Host "  $($Log.Name) - $SizeMB MB - $($Log.LastWriteTime)" -ForegroundColor Gray
    }

    $RemainingSizeMB = [math]::Round($RemainingSize / 1MB, 2)
    Write-Host ""
    Write-Host "Total remaining log size: $RemainingSizeMB MB" -ForegroundColor Cyan
    Write-Host ""

    exit 0

} catch {
    Write-Host ""
    Write-Host "=================================================================================" -ForegroundColor Red
    Write-Host "ERROR" -ForegroundColor Red
    Write-Host "=================================================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

<#
.SYNOPSIS
    Clean up old MongoDB log files to save disk space

.DESCRIPTION
    This script removes old MongoDB log files based on retention policy.
    By default, it keeps the last 7 days of logs.

    MongoDB rotates logs when logRotate: rename is configured.
    Rotated logs follow the pattern: mongod.log.YYYY-MM-DDTHH-mm-ss

.PARAMETER RetentionDays
    Number of days to keep log files (default: 7)

.PARAMETER LogDirectory
    Path to MongoDB log directory (default: C:\MongoDB\log)

.PARAMETER Help
    Show help message

.EXAMPLE
    .\cleanup_logs.ps1
    Clean up logs older than 7 days (default)

.EXAMPLE
    .\cleanup_logs.ps1 -RetentionDays 3
    Keep only the last 3 days of logs

.EXAMPLE
    .\cleanup_logs.ps1 -LogDirectory "D:\MongoDB\log" -RetentionDays 14
    Clean up logs in custom directory, keep 14 days

.EXAMPLE
    # Schedule weekly cleanup (run as Administrator)
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -File C:\MongoDB\cleanup_logs.ps1"

    $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am

    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
        -LogonType ServiceAccount -RunLevel Highest

    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

    Register-ScheduledTask -TaskName "MongoDB-Log-Cleanup" `
        -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings `
        -Description "Weekly cleanup of old MongoDB log files to save disk space"

.NOTES
    Author: WildDuck Deployment
    Requires: MongoDB with logRotate: rename configured

    This script is designed to work with MongoDB's rename log rotation.
    When MongoDB rotates logs, it renames the current log file to include
    a timestamp and creates a new mongod.log file.

    To force log rotation manually:
        mongosh --eval "db.adminCommand({ logRotate: 1 })"

    Or restart MongoDB service:
        Restart-Service MongoDB
#>
