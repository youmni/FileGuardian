# FileGuardian - User Guide

Welcome to FileGuardian, your comprehensive backup and integrity monitoring solution for Windows. This guide will help you get started with both manual operations and scheduled automated backups.

---

## Table of Contents

- [FileGuardian - User Guide](#fileguardian---user-guide)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Quick Start](#quick-start)
  - [Configuration](#configuration)
    - [Configuration Hierarchy](#configuration-hierarchy)
    - [Credential Storage](#credential-storage)
    - [Global Settings](#global-settings)
    - [Exclusion Patterns](#exclusion-patterns)
  - [Manual Operations](#manual-operations)
    - [Backup Operations](#backup-operations)
      - [1. Full Backup](#1-full-backup)
      - [2. Incremental Backup](#2-incremental-backup)
    - [Verify Operations](#verify-operations)
    - [Report Operations](#report-operations)
    - [Restore Operations](#restore-operations)
    - [Cleanup Operations](#cleanup-operations)
  - [Scheduled Backups](#scheduled-backups)
    - [Configuration](#configuration-1)
    - [Configuration Options](#configuration-options)
    - [Schedule Frequencies](#schedule-frequencies)
      - [Daily Backups](#daily-backups)
      - [Weekly Backups](#weekly-backups)
      - [Hourly Backups](#hourly-backups)
    - [Registering Scheduled Tasks](#registering-scheduled-tasks)
    - [Important: Scheduling Best Practices](#important-scheduling-best-practices)
    - [Task Behavior](#task-behavior)
  - [Configuration](#configuration-2)
    - [Configuration Hierarchy](#configuration-hierarchy-1)
    - [Global Settings](#global-settings-1)
    - [Exclusion Patterns](#exclusion-patterns-1)
  - [Reports](#reports)
    - [Report Formats](#report-formats)
      - [HTML Report (Recommended)](#html-report-recommended)
      - [JSON Report](#json-report)
      - [CSV Report](#csv-report)
    - [Report Contents](#report-contents)
    - [Digital Signatures](#digital-signatures)
  - [Best Practices](#best-practices)
    - [Backup Strategy](#backup-strategy)
    - [Security](#security)
    - [Performance](#performance)
    - [Retention](#retention)
  - [Support](#support)

---

## Getting Started

### Prerequisites

- Windows PowerShell 5.1 or later
- Administrator privileges (for scheduled tasks)
- Sufficient disk space for backups

### Quick Start

1. Open PowerShell in the FileGuardian directory

2. Load the FileGuardian module and run your first backup.

```powershell
Import-Module <path-to-module>\FileGuardian.psm1
```
3. Run your first backup with FileGuardian
```powershell
$backupParams = @{
  Action = 'Backup'
  SourcePath = 'C:\FileGuardian'
  DestinationPath = 'D:\FileGuardian\backups'
  BackupName = 'FileGuardian'
  Compress = $true
}
Invoke-FileGuardian @backupParams
```

**What This Does:**
- Backs up files from the specified `-SourcePath`
- Stores backup files in the configured `-DestinationPath`
- Optional `-Compress` creates compressed archives
- Tracks file integrity with SHA256 hashes and signs reports

---

## Configuration

### Configuration Hierarchy

FileGuardian uses a **3-level priority system** for settings:

1. **Environment variable or explicitly given config path** `FILEGUARDIAN_CONFIG_PATH` (highest priority) — set this to a custom config file path to override defaults. You can also give a config path to FileGuardian.
2. **Command-line parameters** — explicit values passed to `Invoke-FileGuardian`.
3. **Hardcoded defaults** (lowest priority) — built-in fallbacks.

You can override the default config path by setting the environment variable `FILEGUARDIAN_CONFIG_PATH`.

```powershell
[System.Environment]::SetEnvironmentVariable('FILEGUARDIAN_CONFIG_PATH','<PATH>', 'User')
```

A sample configuration file is included in this repository at `config\backup-config.json` — copy or edit it to define your scheduled backups and defaults.

### Credential Storage

Install and use the CredentialManager module to securely store the report signing secret:

```powershell
Install-Module -Name CredentialManager -Scope CurrentUser
$bytes = New-Object byte[] 32; [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$secret = [Convert]::ToBase64String($bytes)
New-StoredCredential -Target "FileGuardian.ReportSigning" -UserName "FileGuardian" -Password $secret -Persist LocalMachine
Get-StoredCredential -Target "FileGuardian.ReportSigning"
```

### Global Settings

Located in `config\backup-config.json`:

```json
{
  "GlobalSettings": {
    "LogDirectory": "C:\\BackupLogs",
    "ReportOutputPath": "C:\\BackupReports",
    "ReportFormat": "JSON",
    "DefaultBackupType": "Full"
  },
  "BackupSettings": {
    "DestinationPath": "C:\\Backups",
    "CompressBackups": false,
    "ExcludePatterns": ["*.tmp", "*.log", "*.bak"],
    "RetentionDays": 30
  }
}
```

### Exclusion Patterns

Common patterns to exclude:

```json
"ExcludePatterns": [
  "*.tmp",
  "*.log",
  "*.cache",
  "Thumbs.db",
  ".DS_Store",
  "node_modules/**",
  ".git/**",
  "bin/**",
  "obj/**"
]
```

---

## Manual Operations

### Backup Operations

FileGuardian supports three types of backups, each with specific use cases.

#### 1. Full Backup

Creates a complete backup of all files in the source directory.

**Basic Usage:**
```powershell
$params = @{
  Action = 'Backup'
  SourcePath = 'C:\Users\YourName\Documents\ProjectFiles'
  DestinationPath = 'D:\Backups\Projects'
  BackupName = 'WeeklyFullBackup'
  ReportFormat = 'HTML'
  Compress = $true
}
Invoke-FileGuardian @params
```

**With All Options:**
```powershell
$params = @{
  Action = 'Backup'
  SourcePath = 'C:\MyData'
  DestinationPath = 'D:\Backups'
  BackupName = 'MyProject'
  BackupType = 'Full'
  ReportFormat = 'HTML'
  ReportOutputPath = 'D:\Reports'
  Compress = $true
  ExcludePatterns = @('*.tmp','*.log','node_modules/**')
}
Invoke-FileGuardian @params
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Action` | Yes | - | Must be `Backup` |
| `-SourcePath` | Yes | - | The directory to backup |
| `-DestinationPath` | No | From config | Where to store the backup |
| `-BackupName` | No | Auto-generated | Custom name for the backup |
| `-BackupType` | No | From config or `Full` | Type: `Full` or `Incremental` |
| `-ReportFormat` | No | From config or `JSON` | Report format: `JSON`, `HTML` or `CSV` |
| `-ReportOutputPath` | No | From config | Where to save the report |
| `-Compress` | No | `false` | Compress backup to ZIP |
| `-ExcludePatterns` | No | From config or N/A | Array of patterns to exclude |
| `-ConfigPath` | No | From env or N/A | Custom config file path |

**When to Use Full Backup:**
- First backup of a new source
- Weekly or monthly comprehensive backups
- When you want a complete standalone backup
- After major changes to your data

**What Gets Tracked:**
- All files in source directory
- File hashes (SHA256)
- File sizes and timestamps
- If previous backup exists: changed/new/deleted files

---

#### 2. Incremental Backup
Backs up only files that changed since the **last backup** (Full or Incremental).

**Basic Usage:**
```powershell
$params = @{
  Action = 'Backup'
  SourcePath = 'C:\Users\YourName\Documents\ProjectFiles'
  DestinationPath = 'D:\Backups\Projects'
  BackupName = 'DailyIncremental'
  BackupType = 'Incremental'
  ReportFormat = 'HTML'
  ReportOutputPath = 'D:\Reports\Projects'
  Compress = $true
}
Invoke-FileGuardian @params
```

**Full Example with Exclusions:**
```powershell
$params = @{
  Action = 'Backup'
  SourcePath = 'C:\Development\WebApp'
  DestinationPath = 'D:\Backups\WebApp'
  BackupName = 'WebApp-Daily'
  BackupType = 'Incremental'
  ReportFormat = 'HTML'
  ReportOutputPath = 'D:\Reports\WebApp'
  Compress = $true
  ExcludePatterns = @('node_modules/**','*.log','.git/**')
}
Invoke-FileGuardian @params
```

**When to Use:**
- Daily backups
- Continuous backup strategy
- When disk space is limited
- For frequently changing files

**How It Works:**
1. Compares current files against `latest.json` state
2. Backs up only **modified**, **new** and **deleted** files
3. Updates the state for next backup

**Backup Chain Example:**
```
Monday:    Full Backup (100 files, 1GB)
Tuesday:   Incremental (5 changed files, 50MB)
Wednesday: Incremental (3 changed files, 20MB)
Thursday:  Incremental (8 changed files, 80MB)
Friday:    Full Backup (104 files, 1.15GB)
```

**Important Notes:**
- Requires a previous backup state (`latest.json`)
- If no previous state exists, automatically performs Full Backup

---

### Verify Operations

Verify the integrity of a backup by checking file hashes.

**Verify Uncompressed Backup:**
```powershell
$verify = @{ Action = 'Verify'; BackupPath = 'D:\Backups\Projects\WeeklyFullBackup_20251214_150000' }
Invoke-FileGuardian @verify
```

**Verify Compressed ZIP Backup:**
```powershell
$verify = @{ Action = 'Verify'; BackupPath = 'D:\Backups\WebApp\WebApp-Daily_20251214_020000.zip' }
Invoke-FileGuardian @verify
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Action` | Yes | Must be `Verify` |
| `-BackupPath` | Yes | Path to backup or ZIP file |

**What Gets Verified:**
- File hashes match the backup's own state file
- No files are corrupted
- No files are missing
- Timestamps and sizes are correct

**Output:**
```
=== Backup Integrity Verification ===
Backup:    C:\FileGuardian\file_guardian_20251230_195352
State:     2025-12-30T19:53:53.9648160+01:00

BackupPath     : C:\FileGuardian\Aklaa\backups\file_guardian_20251230_195352
StateTimestamp : 2025-12-30T19:53:53.9648160+01:00
IsIntact       : True
Corrupted      : {}
Missing        : {}
Extra          : {}
Summary        : @{VerifiedCount=316; CorruptedCount=0; MissingCount=0; ExtraCount=0; TotalSourceFiles=316}
```

**When to Verify:**
- After each backup there is aan automatic integrity check
- To check backup health manually

---

### Report Operations

Verify the digital signature of a backup report.

**Verify HTML Report:**
```powershell
$r = @{ Action = 'Report'; ReportPath = 'D:\Reports\Projects\WeeklyFullBackup_20251214_150000_20251214_150230_report.html' }
Invoke-FileGuardian @r
```

**Verify JSON Report:**
```powershell
$r = @{ Action = 'Report'; ReportPath = 'D:\Reports\WebApp\WebApp-Daily_20251214_020000_20251214_020145_report.json' }
Invoke-FileGuardian @r
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Action` | Yes | Must be `Report` |
| `-ReportPath` | Yes | Path to the report file |

**What Gets Verified:**
- Report signature (HMACSHA256 hash)
- Report hasn't been tampered with
- Signature file exists

**Output:**
```
Report signature is VALID
  Report: fileguardian_20251230_194139_20251230_194142_report.html
  Signed: 2025-12-30T19:41:42.9357059+01:00
  By: User@USER
  ReportPath   : C:\FileGuardian\reports\fileguardian_20251230_194139_20251230_194142_report.html
  IsValid      : True
  ExpectedHash : CF1537F97A154A3DE88CA5EF113521F19198EFA735ECB777287FC1B732898271
  ActualHash   : CF1537F97A154A3DE88CA5EF113521F19198EFA735ECB777287FC1B732898271
  Algorithm    : SHA256
  SignedAt     : 2025-12-30T19:41:42.9357059+01:00
  SignedBy     : User@USER
```

---

### Restore Operations

Restore files from a backup. Use the `Restore` action and provide the `-BackupDirectory` and `-RestoreDirectory`.

**Restore Backups:**
```powershell
$restore = @{
  Action = 'Restore'
  BackupDirectory = "C:\Temp\aklaa\backups"
  RestoreDirectory = 'C:\Temp\aklaa\restore'
}
Invoke-FileGuardian @restore
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Action` | Yes | Must be `Restore` |
| `-BackupDirectory` | Yes | Path to backup folder |
| `-RestoreDirectory` | Yes | Where to restore files and folders |

**What Gets Restored:**
- Files and directories

### Cleanup Operations

Manually trigger cleanup to remove old backups based on retention settings. The `Cleanup` action can read settings from the configuration for the named backup, or you can provide the directory and retention days explicitly.

**Manual Cleanup Examples:**
```powershell
$cleanupParams = @{
  Action = 'Cleanup'
  BackupName = 'DailyDocuments'
  ConfigPath = 'C:\config'
}
Invoke-FileGuardian @cleanupParams

$cleanupParams = @{
  Action = 'Cleanup'
  BackupName = 'DailyDocuments'
  RetentionDays = 30
  CleanupBackupDirectory = 'D:\Backups\Documents'
  ConfigPath = 'C:\config'
}
Invoke-FileGuardian @cleanupParams
```

**Notes:**
- A config file needs to be added manually or with env.

## Scheduled Backups

Automate your backups with Windows Task Scheduler.

### Configuration

Edit `config\backup-config.json` to define your scheduled backups:

```json
{
  "ScheduledBackups": [
    {
      "Name": "DailyDocuments",
      "Enabled": true,
      "SourcePath": "C:\\Users\\YourName\\Documents",
      "BackupPath": "D:\\Backups\\Documents",
      "ReportOutputPath": "D:\\Reports\\Documents",
      "BackupType": "Incremental",
      "Schedule": {
        "Frequency": "Daily",
        "Time": "02:00",
        "DaysOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
      },
      "CompressBackups": true,
      "ExcludePatterns": ["*.tmp", "*.log", "*.cache", "node_modules/**"],
      "ReportFormat": "HTML",
      "RetentionDays": 30
    }
  ]
}
```

### Configuration Options

| Option | Required | Description |
|--------|----------|-------------|
| `Name` | Yes | Unique identifier for the scheduled backup |
| `Enabled` | Yes | `true` or `false` - enable/disable the task |
| `SourcePath` | Yes | Directory to backup |
| `BackupPath` | Yes | Where to store backups |
| `ReportOutputPath` | Yes | Where to save reports |
| `BackupType` | Yes | `Full` or `Incremental` |
| `Schedule.Frequency` | Yes | `Daily`, `Weekly`, or `Hourly` |
| `Schedule.Time` | Yes | Time in 24-hour format (e.g., "14:30") |
| `Schedule.DaysOfWeek` | For Weekly | Array of days: `["Monday", "Friday"]` |
| `CompressBackups` | Yes | `true` or `false` |
| `ExcludePatterns` | No | Array of exclusion patterns |
| `ReportFormat` | Yes | `JSON`, `HTML` or `CSV` |
| `RetentionDays` | Yes | How many days to keep backups |

### Schedule Frequencies

#### Daily Backups
```json
"Schedule": {
  "Frequency": "Daily",
  "Time": "02:00",
  "DaysOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
}
```

#### Weekly Backups
```json
"Schedule": {
  "Frequency": "Weekly",
  "Time": "03:00",
  "DaysOfWeek": ["Sunday"]
}
```

#### Hourly Backups
```json
"Schedule": {
  "Frequency": "Hourly",
  "Time": "00:00"
}
```
*Note: Time indicates when the hourly repetition starts*

### Registering Scheduled Tasks

**Register All Scheduled Backups:**
```powershell
# Run as Administrator!
# Create or update scheduled tasks from the config file
Invoke-FileGuardian -Action Schedule -ConfigPath ".\config\backup-config.json"
```

**Register Specific Backup:**
```powershell
Invoke-FileGuardian -Action Schedule -BackupName "DailyDocuments"
```

**Remove All Tasks:**
```powershell
Invoke-FileGuardian -Action Schedule -Remove
```

### Important: Scheduling Best Practices

**Avoid scheduling multiple backups at the same time.** Simultaneous backups compete for system resources.

**Recommended:** Stagger backup times by 30 minutes.

```json
// Good: Staggered times
{ "Name": "Documents", "Schedule": { "Time": "02:00" } }
{ "Name": "Projects", "Schedule": { "Time": "02:30" } }
{ "Name": "Photos", "Schedule": { "Time": "03:00" } }
```

**Remove Specific Task:**
```powershell
Invoke-FileGuardian -Action Schedule -BackupName "DailyDocuments" -Remove
```

### Task Behavior

**Missed Tasks:**
- Uses `-StartWhenAvailable` flag

**Automatic Retention Cleanup:**

For each backup task, FileGuardian creates TWO scheduled tasks:

1. **Backup Task** (e.g., `FileGuardian_DailyDocuments`)
   - Runs according to your schedule (daily, weekly, etc.)
   - Performs the actual backup operation

2. **Cleanup Task** (e.g., `FileGuardian_Cleanup_DailyDocuments`)
   - Automatically triggered when backup completes successfully
   - Removes old backups based on `RetentionDays` setting
   - Event-driven: only runs after successful backup
   - No manual intervention needed

**How It Works:**
```
1. Backup task runs at scheduled time (e.g., 02:00)
2. Backup completes successfully
3. Windows logs "Task Completed" event (Event ID 102)
4. Cleanup task automatically triggers
5. Old backups (older than RetentionDays) are removed
6. Logs show: "Deleted X backup(s), freed Y MB"
```

**Task Monitoring:**
```powershell
# View all FileGuardian scheduled tasks (backup + cleanup)
Get-ScheduledTask | Where-Object { $_.TaskName -like "FileGuardian_*" }

# View task details
Get-ScheduledTaskInfo -TaskName "FileGuardian_DailyDocuments"

# View cleanup task details
Get-ScheduledTaskInfo -TaskName "FileGuardian_Cleanup_DailyDocuments"
```

---
## Configuration

### Configuration Hierarchy

FileGuardian uses a **3-level priority system** for settings:

1. **Command-line parameters** (highest priority) - Explicitly specified values
2. **Config file values** - Defaults from `backup-config.json`
3. **Hardcoded defaults** (lowest priority) - Built-in fallbacks

**Example:** If you don't specify `-ReportFormat`, FileGuardian checks the config file. If not in config, it uses `JSON` as default.

### Global Settings

Located in `config\backup-config.json`:

```json
{
  "GlobalSettings": {
    "LogDirectory": "C:\\BackupLogs",
    "ReportOutputPath": "C:\\BackupReports",
    "ReportFormat": "JSON",
    "DefaultBackupType": "Full"
  },
  "BackupSettings": {
    "DestinationPath": "C:\\Backups",
    "CompressBackups": false,
    "ExcludePatterns": ["*.tmp", "*.log", "*.bak"],
    "RetentionDays": 30
  }
}
```

### Exclusion Patterns

Common patterns to exclude:

```json
"ExcludePatterns": [
  "*.tmp",           // Temporary files
  "*.log",           // Log files
  "*.cache",         // Cache files
  "Thumbs.db",       // Windows thumbnails
  ".DS_Store",       // Mac system files
  "node_modules/**", // Node.js dependencies
  ".git/**",         // Git repository
  "bin/**",          // Build output
  "obj/**"           // Compiler output
]
```

---
## Reports

Every backup automatically generates a signed report.

### Report Formats

#### HTML Report (Recommended)
- Professional visual layout
- Easy to read in browser
- Statistics
- Corruption warnings highlighted

**Example:**
```powershell
-ReportFormat HTML
```

#### JSON Report
- Machine-readable
- Easy to parse programmatically
- Complete data structure
- Good for automation

**Example:**
```powershell
-ReportFormat JSON
```

#### CSV Report
- Excel-compatible
- Easy data analysis
- Tabular format
- Good for reporting

**Example:**
```powershell
-ReportFormat CSV
```

### Report Contents

All reports include:

**Backup Details:**
- Backup name and type
- Timestamp and duration
- Source and destination paths
- Success/failure status

**Statistics:**
- Files backed up
- Total size (MB)
- Compression ratio (if compressed)
- Compressed size

**File Changes** (Incremental/Differential/Full with previous state):
- Modified files (count and list)
- New files (count and list)
- Deleted files (count and list)

**Integrity Information:**
- State saved (yes/no)
- State directory location
- Previous backups verified
- Corrupted backups detected

**System Information:**
- Computer name
- User name
- OS version
- PowerShell version

### Digital Signatures

Every report is automatically signed with SHA256 hash:
- Prevents tampering
- Ensures authenticity
- Signature stored in `.sig` file
- Verify with `Report` action

---

## Best Practices

### Backup Strategy

**Recommended Schedule:**
```
Weekly:  Full Backup (Sunday 03:00)
Daily:   Incremental Backup (02:00)
```

**Directory Organization:**

FileGuardian expects each backup source to have its own dedicated backup directory. This ensures proper state tracking and integrity verification.

**Correct Structure:**
```
D:\Backups\
  ├── ProjectA\
  │   ├── ProjectA_20251201_120000\
  │   ├── ProjectA_20251202_120000\
  │   └── ProjectA_20251203_120000\
  └── ProjectB\
      ├── ProjectB_20251201_120000\
      ├── ProjectB_20251202_120000\
      └── ProjectB_20251203_120000\
```

**Incorrect - Mixed Sources:**
```
D:\Backups\
  ├── ProjectA_20251201_120000\
  ├── ProjectB_20251201_120000\
  ├── ProjectA_20251202_120000\
  └── ProjectB_20251202_120000\
```

**Why This Matters:**
- State files (`latest.json`, `prev.json`) track a single source
- Incremental backups compare against the correct previous state
- Integrity verification works properly
- Reports are accurate and meaningful
- 
### Security

**Monitor Integrity:**
- Check reports regularly
- Verify critical backups monthly

### Performance

**Optimize Exclusions:**
```powershell
-ExcludePatterns "*.tmp","*.log","*.cache","node_modules/**",".git/**","bin/**","obj/**"
```

**Large Backups:**
- Use incremental for daily backups
- Schedule during off-hours
- Consider compression for text-heavy data

### Retention

**Clean old backups manually:**
```powershell
# Manual cleanup (example)
Get-ChildItem "D:\Backups" -Filter "*.zip" | 
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item
```

---

## Support

For issues, feature requests or questions:
- Check logs in configured `LogDirectory`
- Review reports for detailed backup information
- Check `README.md` for author(s)