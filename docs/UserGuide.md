# FileGuardian - User Guide

Welcome to FileGuardian, your comprehensive backup and integrity monitoring solution for Windows. This guide will help you get started with both manual operations and scheduled automated backups.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Manual Operations](#manual-operations)
   - [Backup Operations](#backup-operations)
   - [Verify Operations](#verify-operations)
   - [Report Operations](#report-operations)
3. [Scheduled Backups](#scheduled-backups)
4. [Configuration](#configuration)
5. [Reports](#reports)
6. [Best Practices](#best-practices)

---

## Getting Started

### Prerequisites

- Windows PowerShell 5.1 or later
- Administrator privileges (for scheduled tasks)
- Sufficient disk space for backups

### Quick Start

1. Open PowerShell in the FileGuardian directory

2. Run your first backup with basic settings:
   ```powershell
      .\Start-FileGuardian.ps1 `
       -Action Backup `
       -SourcePath "C:\Users\Linus\Documents\Uni\3Bachelor\FileGuardian" `
       -DestinationPath "D:\Linus\Backups\FileGuardian" `
       -BackupName "FileGuardian" `
       -ReportFormat HTML `
       -ReportOutputPath "D:\Linus\Reports" `
       -Compress
   ```

**What This Does:**
- Backs up all files from `C:\Users\Linus\Documents\Uni\3Bachelor\FileGuardian`
- Stores backup in `D:\Linus\Backups\FileGuardian_[timestamp].zip`
- Generates HTML report in `D:\Linus\Reports`
- Compresses the backup
- Tracks file integrity with SHA256 hashes
- Automatically signs the report

---

## Manual Operations

### Backup Operations

FileGuardian supports three types of backups, each with specific use cases.

#### 1. Full Backup

Creates a complete backup of all files in the source directory.

**Basic Usage:**
```powershell
.\Start-FileGuardian.ps1 `
    -Action Backup `
    -SourcePath "C:\Users\YourName\Documents\ProjectFiles" `
    -DestinationPath "D:\Backups\Projects" `
    -BackupName "WeeklyFullBackup" `
    -ReportFormat HTML `
    -Compress
```

**With All Options:**
```powershell
.\Start-FileGuardian.ps1 `
    -Action Backup `
    -SourcePath "C:\MyData" `
    -DestinationPath "D:\Backups" `
    -BackupName "MyProject" `
    -BackupType Full `
    -ReportFormat HTML `
    -ReportOutputPath "D:\Reports" `
    -Compress `
    -ExcludePatterns "*.tmp","*.log","node_modules/**"
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Action` | Yes | - | Must be `Backup` |
| `-SourcePath` | Yes | - | The directory to backup |
| `-DestinationPath` | No | From config | Where to store the backup |
| `-BackupName` | No | Auto-generated | Custom name for the backup |
| `-BackupType` | No | From config (`Full`) | Type: `Full` or `Incremental` |
| `-ReportFormat` | No | From config (`JSON`) | Report format: `JSON`, `HTML`, or `CSV` |
| `-ReportOutputPath` | No | From config | Where to save the report |
| `-Compress` | No | `false` | Compress backup to ZIP |
| `-ExcludePatterns` | No | From config | Array of patterns to exclude |
| `-ConfigPath` | No | `config\backup-config.json` | Custom config file path |

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
.\Start-FileGuardian.ps1 `
    -Action Backup `
    -SourcePath "C:\Users\YourName\Documents\ProjectFiles" `
    -DestinationPath "D:\Backups\Projects" `
    -BackupName "DailyIncremental" `
    -BackupType Incremental `
    -ReportFormat HTML `
    -ReportOutputPath "D:\Reports\Projects" `
    -Compress
```

**Full Example with Exclusions:**
```powershell
.\Start-FileGuardian.ps1 `
    -Action Backup `
    -SourcePath "C:\Development\WebApp" `
    -DestinationPath "D:\Backups\WebApp" `
    -BackupName "WebApp-Daily" `
    -BackupType Incremental `
    -ReportFormat HTML `
    -ReportOutputPath "D:\Reports\WebApp" `
    -Compress `
    -ExcludePatterns "node_modules/**","*.log",".git/**"
```

**When to Use:**
- Daily backups
- Continuous backup strategy
- When disk space is limited
- For frequently changing files

**How It Works:**
1. Compares current files against `latest.json` state
2. Backs up only **modified** and **new** files
3. Tracks **deleted** files (in report only)
4. Updates the state for next backup

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
- Deleted files are tracked but not backed up

---

### Verify Operations

Verify the integrity of a backup by checking file hashes.

**Verify Uncompressed Backup:**
```powershell
.\Start-FileGuardian.ps1 `
    -Action Verify `
    -BackupPath "D:\Backups\Projects\WeeklyFullBackup_20251214_150000"
```

**Verify Compressed ZIP Backup:**
```powershell
.\Start-FileGuardian.ps1 `
    -Action Verify `
    -BackupPath "D:\Backups\WebApp\WebApp-Daily_20251214_020000.zip"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Action` | Yes | Must be `Verify` |
| `-BackupPath` | Yes | Path to backup directory or ZIP file |

**What Gets Verified:**
- File hashes match the backup's own state file
- No files are corrupted
- No files are missing
- Timestamps and sizes are correct

**Output:**
```
✓ Backup Integrity: INTACT
  Files Verified: 308
  Corrupted: 0
  Missing: 0
```

**When to Verify:**
- After creating a backup (automatic)
- Before restoring
- Periodically to check backup health
- After copying backups to new location

---

### Report Operations

Verify the digital signature of a backup report.

**Verify HTML Report:**
```powershell
.\Start-FileGuardian.ps1 `
    -Action Report `
    -ReportPath "D:\Reports\Projects\WeeklyFullBackup_20251214_150000_20251214_150230_report.html"
```

**Verify JSON Report:**
```powershell
.\Start-FileGuardian.ps1 `
    -Action Report `
    -ReportPath "D:\Reports\WebApp\WebApp-Daily_20251214_020000_20251214_020145_report.json"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Action` | Yes | Must be `Report` |
| `-ReportPath` | Yes | Path to the report file |

**What Gets Verified:**
- Report signature (SHA256 hash)
- Report hasn't been tampered with
- Signature file exists

**Output:**
```
✓ Report Signature: VALID
  Algorithm: SHA256
  Hash: 30B28002B1683E02...
```

---

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
| `BackupType` | Yes | `Full`, `Incremental`, or `Differential` |
| `Schedule.Frequency` | Yes | `Daily`, `Weekly`, or `Hourly` |
| `Schedule.Time` | Yes | Time in 24-hour format (e.g., "14:30") |
| `Schedule.DaysOfWeek` | For Weekly | Array of days: `["Monday", "Friday"]` |
| `CompressBackups` | Yes | `true` or `false` |
| `ExcludePatterns` | No | Array of exclusion patterns |
| `ReportFormat` | Yes | `JSON`, `HTML`, or `CSV` |
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
.\tools\Register-ScheduledTask.ps1
```

**Register Specific Backup:**
```powershell
.\tools\Register-ScheduledTask.ps1 -BackupName "DailyDocuments"
```

**Remove All Tasks:**
```powershell
.\tools\Register-ScheduledTask.ps1 -Remove
```

**Remove Specific Task:**
```powershell
.\tools\Register-ScheduledTask.ps1 -BackupName "DailyDocuments" -Remove
```

### Task Behavior

**Background Execution:**
- Runs as SYSTEM account
- No password prompt required
- Runs even when user is not logged in
- Will wake computer from sleep (if enabled)
- Continues on battery power

**Missed Tasks:**
- If computer was off, task runs when it starts
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

**Example Configuration:**
```powershell
# ProjectA backups
.\Start-FileGuardian.ps1 -Action Backup `
    -SourcePath "C:\Work\ProjectA" `
    -DestinationPath "D:\Backups\ProjectA" `
    -BackupName "ProjectA"

# ProjectB backups
.\Start-FileGuardian.ps1 -Action Backup `
    -SourcePath "C:\Work\ProjectB" `
    -DestinationPath "D:\Backups\ProjectB" `
    -BackupName "ProjectB"
```

### Retention Management

**Automatic Cleanup:**
- Configured via `RetentionDays` in config
- Can be set globally or per scheduled backup
- Cleanup runs automatically after each successful backup
- No manual intervention required

**What Gets Cleaned:**
- Backup directories older than RetentionDays
- Compressed ZIP backups older than RetentionDays
- Orphaned state files (states without corresponding backups)
- **Always kept:** `latest.json` and `prev.json` state files

### Security

**Monitor Integrity:**
- Check reports regularly
- Verify critical backups monthly
- Review cleanup logs to ensure proper retention

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

**Clean Old Backups:**
```powershell
# Manual cleanup (example)
Get-ChildItem "D:\Backups" -Filter "*.zip" | 
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item
```

---

## Support

For issues, feature requests, or questions:
- Check logs in configured `LogDirectory`
- Review reports for detailed backup information
- Check `README.md` for author(s)