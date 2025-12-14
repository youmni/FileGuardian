<#
.SYNOPSIS
    Registers scheduled tasks for automatic backups.

.DESCRIPTION
    This script reads the backup-config.json and creates Windows Scheduled Tasks
    for each configured automatic backup.

.EXAMPLE
    .\Register-ScheduledTask.ps1
    Registers all scheduled backups from the config

.EXAMPLE
    .\Register-ScheduledTask.ps1 -BackupName "DailyColruytBackup"
    Registers only the specific backup task
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\..\config\backup-config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$BackupName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Remove
)

# Check if the script is running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator!"
    exit 1
}

# Read the configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

if (-not $config.ScheduledBackups) {
    Write-Warning "No scheduled backups found in configuration."
    exit 0
}

# Determine which backups to process
$backupsToProcess = if ($BackupName) {
    $config.ScheduledBackups | Where-Object { $_.Name -eq $BackupName }
    if (-not $backupsToProcess) {
        Write-Error "Backup '$BackupName' not found in configuration."
        exit 1
    }
    $backupsToProcess
} else {
    $config.ScheduledBackups
}

# Project root directory
$projectRoot = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $projectRoot "Start-FileGuardian.ps1"

foreach ($backup in $backupsToProcess) {
    if (-not $backup.Enabled -and -not $Remove) {
        Write-Host "Skipping: $($backup.Name) (not enabled)" -ForegroundColor Yellow
        continue
    }

    $taskName = "FileGuardian_$($backup.Name)"
    
    # Remove existing task if it exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Removing existing task: $taskName" -ForegroundColor Cyan
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    if ($Remove) {
        Write-Host "Task removed: $taskName" -ForegroundColor Green
        continue
    }

    # Build the PowerShell command
    $arguments = @(
        "-NoProfile"
        "-ExecutionPolicy Bypass"
        "-File `"$scriptPath`""
        "-Action Backup"
        "-SourcePath `"$($backup.SourcePath)`""
        "-BackupName `"$($backup.Name)`""
        "-BackupType $($backup.BackupType)"
        "-ReportFormat $($backup.ReportFormat)"
    )
    
    if ($backup.CompressBackups) {
        $arguments += "-Compress"
    }

    $argumentString = $arguments -join " "

    # Create the action
    $action = New-ScheduledTaskAction `
        -Execute "PowerShell.exe" `
        -Argument $argumentString

    # Parse time (HH:mm format)
    $timeParts = $backup.Schedule.Time -split ':'
    $hour = [int]$timeParts[0]
    $minute = [int]$timeParts[1]

    # Create the trigger based on frequency
    $trigger = switch ($backup.Schedule.Frequency) {
        "Daily" {
            New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddHours($hour).AddMinutes($minute))
        }
        "Weekly" {
            $daysOfWeek = $backup.Schedule.DaysOfWeek | ForEach-Object {
                switch ($_) {
                    "Monday" { [System.DayOfWeek]::Monday }
                    "Tuesday" { [System.DayOfWeek]::Tuesday }
                    "Wednesday" { [System.DayOfWeek]::Wednesday }
                    "Thursday" { [System.DayOfWeek]::Thursday }
                    "Friday" { [System.DayOfWeek]::Friday }
                    "Saturday" { [System.DayOfWeek]::Saturday }
                    "Sunday" { [System.DayOfWeek]::Sunday }
                }
            }
            New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At ([datetime]::Today.AddHours($hour).AddMinutes($minute))
        }
        "Hourly" {
            $trigger = New-ScheduledTaskTrigger -Once -At ([datetime]::Today.AddHours($hour).AddMinutes($minute))
            $trigger.Repetition = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) | Select-Object -ExpandProperty Repetition
            $trigger
        }
        default {
            Write-Error "Unknown frequency: $($backup.Schedule.Frequency)"
            continue
        }
    }

    # Set the principal (run as SYSTEM or current user)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest

    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false `
        -ExecutionTimeLimit (New-TimeSpan -Hours 4)

    # Register the task
    try {
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Description "FileGuardian automatic backup: $($backup.Name)" `
            -Force | Out-Null

        Write-Host "Task registered: $taskName" -ForegroundColor Green
        Write-Host "   Source: $($backup.SourcePath)" -ForegroundColor Gray
        Write-Host "   Schedule: $($backup.Schedule.Frequency) at $($backup.Schedule.Time)" -ForegroundColor Gray
        Write-Host "   Type: $($backup.BackupType)" -ForegroundColor Gray
    }
    catch {
        Write-Error "Error registering task '$taskName': $_"
    }
}

Write-Host "`nRegistered tasks overview:" -ForegroundColor Cyan
Get-ScheduledTask | Where-Object { $_.TaskName -like "FileGuardian_*" } | 
    Select-Object TaskName, State, @{Name='NextRun';Expression={(Get-ScheduledTaskInfo -TaskName $_.TaskName).NextRunTime}} |
    Format-Table -AutoSize