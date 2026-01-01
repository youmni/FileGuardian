function Register-BackupSchedule {
    <#
    .SYNOPSIS
        Registers Windows Scheduled Tasks for automatic backups.
    
    .DESCRIPTION
        Creates scheduled tasks based on configuration file. Each backup gets two tasks:
        1. Main backup task that runs on schedule
        2. Cleanup task that runs automatically after backup completes
    
    .PARAMETER ConfigPath
        Path to the configuration file. Defaults to config/backup-config.json
    
    .PARAMETER BackupName
        Optional: Register only a specific backup by name.
    
    .PARAMETER Remove
        If specified, removes the scheduled tasks instead of creating them.
    
    .EXAMPLE
        Register-BackupSchedule
        Registers all enabled backups from config
    
    .EXAMPLE
        Register-BackupSchedule -BackupName "DailyDocuments"
        Registers only the DailyDocuments backup
    
    .EXAMPLE
        Register-BackupSchedule -Remove
        Removes all FileGuardian scheduled tasks
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath,
        
        [Parameter()]
        [string]$BackupName,
        
        [Parameter()]
        [switch]$Remove
    )
    
    begin {
        # Check for Administrator privileges
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            throw "This operation requires Administrator privileges. Please run as Administrator."
        }
        
        try {
            if ($ConfigPath) {
                $config = Read-Config -ConfigPath $ConfigPath
            }
            else {
                $config = Read-Config
            }
        }
        catch {
            throw "Failed to load configuration via Read-Config: $_"
        }

        if (-not $config -or -not $config.ScheduledBackups) {
            Write-Warning "No scheduled backups found in configuration."
            return
        }
        
        # Get project root for script path
        $moduleRoot = Split-Path -Parent $PSScriptRoot
        $projectRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
        $modulePath = Join-Path $projectRoot "src\FileGuardian.psm1"
    
        
        Write-Log -Message "=== FileGuardian Schedule Management ===" -Level Info
    }
    
    process {
        # Determine which backups to process
        $backupsToProcess = if ($BackupName) {
            $found = $config.ScheduledBackups | Where-Object { $_.Name -eq $BackupName }
            if (-not $found) {
                throw "Backup '$BackupName' not found in configuration."
            }
            $found
        } else {
            $config.ScheduledBackups
        }
        
        foreach ($backup in $backupsToProcess) {
            if (-not $backup.Enabled -and -not $Remove) {
                Write-Log -Message "Skipping: $($backup.Name) (not enabled in config)" -Level Info
                continue
            }
            
            $taskName = "FileGuardian_$($backup.Name)"
            $cleanupTaskName = "FileGuardian_Cleanup_$($backup.Name)"
            
            # Remove existing tasks if they exist
            $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($existingTask) {
                Write-Log -Message "Removing existing backup task: $taskName" -Level Info
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
            
            $existingCleanup = Get-ScheduledTask -TaskName $cleanupTaskName -ErrorAction SilentlyContinue
            if ($existingCleanup) {
                Write-Log -Message "Removing existing cleanup task: $cleanupTaskName" -Level Info
                Unregister-ScheduledTask -TaskName $cleanupTaskName -Confirm:$false
            }
            
            if ($Remove) {
                Write-Log -Message "Tasks removed for: $($backup.Name)" -Level Success
                continue
            }
            
            # === CREATE MAIN BACKUP TASK ===
            
            # Build PowerShell -Command that imports the module and calls Invoke-FileGuardian
            $cmdParts = @()
            $cmdParts += "Import-Module '$modulePath'"
            $invoke = "Invoke-FileGuardian -Action Backup -SourcePath '$($backup.SourcePath)' -BackupName '$($backup.Name)' -BackupType '$($backup.BackupType)' -ReportFormat '$($backup.ReportFormat)'"

            if ($backup.BackupPath) {
                $invoke += " -DestinationPath '$($backup.BackupPath)'"
            }

            if ($backup.ReportOutputPath) {
                $invoke += " -ReportOutputPath '$($backup.ReportOutputPath)'"
            }

            if ($backup.CompressBackups) {
                $invoke += " -Compress"
            }

            if ($backup.ExcludePatterns) {
                $excludeList = ($backup.ExcludePatterns | ForEach-Object { "'$_'" }) -join ','
                $invoke += " -ExcludePatterns @($excludeList)"
            }

            $cmdParts += $invoke
            $command = $cmdParts -join '; '
            $argumentString = '-NoProfile -ExecutionPolicy Bypass -Command "' + $command + '"'
            
            $actionParams = @{
                Execute = 'PowerShell.exe'
                Argument = $argumentString
            }
            $action = New-ScheduledTaskAction @actionParams
            
            # Parse time (HH:mm format)
            $timeParts = $backup.Schedule.Time -split ':'
            $hour = [int]$timeParts[0]
            $minute = [int]$timeParts[1]
            
            # Create trigger based on frequency
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
                    throw "Unknown frequency: $($backup.Schedule.Frequency)"
                }
            }
            
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType S4U -RunLevel Highest
            Write-Log -Message "Registering tasks to run as user: $currentUser (S4U)" -Level Info

            $settingsParams = @{
                AllowStartIfOnBatteries = $true
                DontStopIfGoingOnBatteries = $true
                StartWhenAvailable = $true
                WakeToRun = $true
                RunOnlyIfNetworkAvailable = $false
                ExecutionTimeLimit = (New-TimeSpan -Hours 4)
                MultipleInstances = 'IgnoreNew'
            }
            $settings = New-ScheduledTaskSettingsSet @settingsParams
            
            # Register backup task
            try {
                $registerParams = @{
                    TaskName = $taskName
                    Action = $action
                    Trigger = $trigger
                    Principal = $principal
                    Settings = $settings
                    Description = "FileGuardian automatic backup: $($backup.Name)"
                    Force = $true
                }
                Register-ScheduledTask @registerParams | Out-Null
                
                Write-Log -Message "Backup task registered: $taskName" -Level Success
                Write-Host "   Source: $($backup.SourcePath)" -ForegroundColor Gray
                Write-Host "   Schedule: $($backup.Schedule.Frequency) at $($backup.Schedule.Time)" -ForegroundColor Gray
                Write-Host "   Type: $($backup.BackupType)" -ForegroundColor Gray
            }
            catch {
                Write-Log -Message "Failed to register backup task '$taskName': $_" -Level Error
                continue
            }
            
            # Create Cleanup Task            
            # Determine retention days
            $retentionDays = if ($backup.RetentionDays) {
                $backup.RetentionDays
            } elseif ($config.BackupSettings.RetentionDays) {
                $config.BackupSettings.RetentionDays
            } else {
                Write-Log -Message "No RetentionDays configured for $($backup.Name), skipping cleanup task" -Level Warning
                continue
            }
            
            # Build cleanup command using module and Invoke-FileGuardian
            $cleanupCmdParts = @()
            $cleanupCmdParts += "Import-Module '$modulePath'"
            $cleanupInvoke = "Invoke-FileGuardian -Action Cleanup -BackupName '$($backup.Name)' -RetentionDays $retentionDays"
            $cleanupCmdParts += $cleanupInvoke
            $cleanupCommand = $cleanupCmdParts -join '; '
            $cleanupArgumentString = '-NoProfile -ExecutionPolicy Bypass -Command "' + $cleanupCommand + '"'
            
            $cleanupActionParams = @{
                Execute = 'PowerShell.exe'
                Argument = $cleanupArgumentString
            }
            $cleanupAction = New-ScheduledTaskAction @cleanupActionParams
            
            # Create dummy trigger (will be replaced with event trigger)
            $cleanupTrigger = New-ScheduledTaskTrigger -AtLogOn
            $cleanupTrigger.Enabled = $false
            
            # Register cleanup task
            try {
                $cleanupRegisterParams = @{
                    TaskName = $cleanupTaskName
                    Action = $cleanupAction
                    Trigger = $cleanupTrigger
                    Principal = $principal
                    Settings = $settings
                    Description = "FileGuardian retention cleanup for: $($backup.Name)"
                    Force = $true
                }
                $cleanupTask = Register-ScheduledTask @cleanupRegisterParams
                
                # Add event-based trigger (runs when backup task completes successfully)
                $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
                $cleanupEventTrigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
                $cleanupEventTrigger.Subscription = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-TaskScheduler/Operational">
    <Select Path="Microsoft-Windows-TaskScheduler/Operational">
      *[System[(EventID=102)]] and *[EventData[Data[@Name='TaskName']='\$taskName']]
    </Select>
  </Query>
</QueryList>
"@
                $cleanupEventTrigger.Enabled = $true
                
                # Update task with event trigger
                $cleanupTask.Triggers = @($cleanupEventTrigger)
                $cleanupTask | Set-ScheduledTask | Out-Null
                
                Write-Log -Message "Cleanup task registered: $cleanupTaskName (triggers after backup)" -Level Success
            }
            catch {
                Write-Log -Message "Failed to register cleanup task '$cleanupTaskName': $_" -Level Error
            }
        }
        
        # Show summary
        Write-Host "`n=== Registered FileGuardian Tasks ===" -ForegroundColor Cyan
        Get-ScheduledTask | Where-Object { $_.TaskName -like "FileGuardian_*" } | 
            Select-Object TaskName, State, @{Name='NextRun';Expression={(Get-ScheduledTaskInfo -TaskName $_.TaskName).NextRunTime}} |
            Format-Table -AutoSize
    }
    
    end {
        Write-Log -Message "=== Schedule Management Complete ===" -Level Info
    }
}