# FileGuardian - Technical Architecture Documentation

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Project Structure](#project-structure)
3. [Architecture Design](#architecture-design)
4. [Module Breakdown](#module-breakdown)
5. [Data Flow & State Management](#data-flow--state-management)

---

## System Overview

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Runtime** | PowerShell | 5.1+ | Cross-compatible scripting environment |
| **Module System** | PowerShell Module Manifest | .psd1 / .psm1 | Modular architecture |
| **Scheduler** | Windows Task Scheduler | Win11 | Automated backup execution |
| **Testing** | Pester | 5.0+ | Unit testing |
| **CI/CD** | GitHub Actions | N/A | Automated testing pipeline |

### Core Principles

1. **Modular Design**: Single-responsibility modules with clear boundaries
2. **Idempotency**: Operations can be safely repeated without side effects
3. **State Management**: Explicit state tracking via JSON files for reproducibility
4. **Fail-Safe**: Defensive programming with comprehensive error handling
5. **Auditability**: All operations logged and reported with digital signatures

---

## Project Structure

```
FileGuardian/
│
├── .github/
│   └── workflows/
│       └── test.yml                      # CI/CD pipeline configuration
│
├── config/
│   └── backup-config.json                # Configuration file (example)
├── build/
│   └── pester-summary.ps1                # For pester output in CI 
│
├── docs/
│   ├── UserGuide.md                      # End-user documentation
│   └── DeveloperGuide.md                 # Developer documentation & Architecture
│
├── src/
│   ├── FileGuardian.psd1                 # PowerShell module manifest
│   ├── FileGuardian.psm1                 # Module entry point & orchestrator
│   │
│   └── Modules/                          # Functional modules (nested)
│       │
│       ├── Backup/                       # Backup operations
│       │   ├── Invoke-FullBackup.ps1
│       │   ├── Invoke-IncrementalBackup.ps1
│       │   ├── Compress-Backup.ps1
│       │   ├── Save-BackupMetadata.ps1
│       │   ├── Test-PreviousBackups.ps1
│       │   ├── Initialize-BackupConfiguration.ps1
│       │   ├── New-BackupReport.ps1
│       │   └── Invoke-IntegrityStateSave.ps1
│       │
│       ├── Integrity/                    # Hash calculation & verification
│       │   ├── Get-FileIntegrityHash.ps1
│       │   ├── Get-NormalizedPath.ps1
│       │   ├── Get-ConsistentRelativePath.ps1
│       │   ├── Save-IntegrityState.ps1
│       │   ├── Compare-BackupIntegrity.ps1
│       │   └── Test-BackupIntegrity.ps1
│       │
│       ├── Reporting/                    # Report generation & signing
│       │   ├── Write-JsonReport.ps1
│       │   ├── Write-HtmlReport.ps1
│       │   ├── Write-CsvReport.ps1
│       │   ├── Get-ReportSigningKey.ps1
│       │   ├── Protect-Report.ps1
│       │   └── Confirm-ReportSignature.ps1
│       │
│       ├── Restore/                      # Restore operations
│       │   ├── Resolve-Backups.ps1
│       │   ├── Get-BackupCandidates.ps1
│       │   ├── Get-MetadataFromFolder.ps1
│       │   ├── Get-MetadataFromZip.ps1
│       │   ├── Convert-BackupTimestampToDateTime.ps1
│       │   └── Invoke-Restore.ps1
│       │
│       ├── Retention/                    # Cleanup & retention management
│       │   ├── Invoke-BackupRetention.ps1
│       │   ├── Invoke-BackupCleanup.ps1
│       │   └── Invoke-RetentionCleanup.ps1
│       │
│       ├── Scheduling/                   # Windows Task Scheduler integration
│       │   └── Register-BackupSchedule.ps1
│       │
│       ├── Config/                       # Configuration management
│       │   └── Read-Config.ps1
│       │
│       └── Logging/                      # Centralized logging
│           └── Write-Log.ps1
│
├── tests/                                # Pester test suites
│   ├── Config.Tests.ps1
│   ├── FullBackup.Tests.ps1
│   ├── IncrementalBackup.Tests.ps1
│   ├── Integrity.Tests.ps1
│   ├── Logging.Tests.ps1
│   ├── Reporting.Tests.ps1
│   ├── Restore.Tests.ps1
│   └── RetentionCleanup.Tests.ps1
│
├── .gitignore
└── README.md
```

### File Naming Conventions

- **Functions**: `Verb-Noun.ps1`
- **Configs**: `kebab-case.json`
- **Logs**: `fileguardian_YYYYMMDD.log`
- **Reports**: `BackupName_YYYYMMDD_HHMMSS_report.{json|html|csv}`

---

## Architecture Design

### Design

1. **Procedural dispatch.**: `Invoke-FileGuardian -Action` routes to appropriate handlers
2. **Hiding internal details**: Main orchistrator hides internal complexity
3. **Event-driven cleanup**: Event-driven cleanup tasks triggered by backup completion when scheduled

---

## Module Breakdown

### 1. FileGuardian.psm1 (Orchestrator)

**Purpose**: Central entry point and action dispatcher

**Key Function**: `Invoke-FileGuardian`

**Parameters**:
- `-Action`: Backup | Verify | Report | Restore | Schedule | Cleanup
- `-SourcePath`, `-DestinationPath`, `-BackupName`, etc. (context-dependent)

**Responsibilities**:
1. Validate parameters based on action
2. Load all nested modules (dot-sourcing .ps1 files)
3. Dispatch to appropriate module function
4. Handle top-level error logging
5. Return structured PSCustomObject results

---

### 2. Backup Module

**Location**: `src/Modules/Backup/`

#### 2.1 Invoke-FullBackup.ps1

**Purpose**: Perform complete backup of source directory

**Key Operations**:
1. Scan source files (with exclusion filtering)
2. Copy all files to destination (temp dir if compression enabled)
3. Save `.backup-metadata.json` with timestamp, type, file count
4. Compress to ZIP (optional)
5. Save integrity state (`Invoke-IntegrityStateSave`)
6. Verify previous backups (`Test-PreviousBackups`)
7. Generate report (`New-BackupReport`)

#### 2.2 Invoke-IncrementalBackup.ps1

**Purpose**: Backup only changed/new files since last backup

**Key Operations**:
1. Load `states/latest.json` (previous state)
2. Scan current source files and calculate hashes
3. Compare with previous state to detect:
   - Changed files (hash mismatch)
   - New files (not in previous state)
   - Deleted files (in previous state, not current)
4. Copy only changed + new files
5. Save metadata including `DeletedFiles` array
6. Update integrity state (becomes new `latest.json`)
7. Verify previous backups and generate report

**Fallback Behavior**: If no `latest.json` exists → delegates to `Invoke-FullBackup`

#### 2.3 Compress-Backup.ps1

**Purpose**: Create ZIP archive from backup folder

#### 2.4 Save-BackupMetadata.ps1

**Purpose**: Write `.backup-metadata.json` inside backup folder/ZIP

**Metadata Structure**:
```json
{
  "BackupType": "Full|Incremental",
  "SourcePath": "C:\\Source",
  "Timestamp": "20251230_120000",
  "FilesBackedUp": 42,
  "DeletedFiles": ["file1.txt"],    // Incremental only
  "FilesIncluded": ["file2.txt"]    // Incremental only
}
```

**Usage**: Required for restore operations and integrity verification

---

### 3. Integrity Module

**Location**: `src/Modules/Integrity/`

#### 3.1 Get-FileIntegrityHash.ps1

**Purpose**: Calculate SHA256 hashes for files with parallel processing

**Key Features**:
1. **Parallel Processing**: Uses runspace pool
2. **Smart Caching**: Reuses hashes for unchanged files (based on LastWriteTime + Size)
3. **Consistent Paths**: Normalizes relative paths via `Get-ConsistentRelativePath`

**Performance**: A lot faster than sequential hashing for large file sets

#### 3.2 Save-IntegrityState.ps1

**Purpose**: Persist current file state to `states/latest.json`

**State Rotation**:
```
Before:                After Save:
latest.json            latest.json (new state)
                       prev.json (old latest)
```

**State Structure**:
```json
{
  "Timestamp": "2025-12-30T12:00:00Z",
  "SourcePath": "C:\\Source",
  "FileCount": 42,
  "TotalSize": 1048576,
  "Files": [
    {
      "Path": "C:\\Source\\file.txt",
      "RelativePath": "file.txt",
      "Hash": "A1B2C3...",
      "Algorithm": "SHA256",
      "Size": 1024,
      "LastWriteTime": "2025-12-30 12:00:00.000"
    }
  ]
}
```

**Important**: Saves backup-specific state as `states/[BackupName].json`

#### 3.3 Test-BackupIntegrity.ps1

**Purpose**: Verify backup files match saved state

**Process**:
1. Load state file (`states/BackupName.json` or `states/latest.json`)
2. Extract ZIP to temp folder if backup is compressed
3. Calculate current hashes for all files in backup
4. Compare with expected hashes from state
5. Categorize results: Verified, Corrupted, Missing, Extra

**Cleanup**: Removes temp extracted folder for ZIPs

---

### 4. Reporting Module

**Location**: `src/Modules/Reporting/`

#### 4.1 Write-JsonReport.ps1 / Write-HtmlReport.ps1 / Write-CsvReport.ps1

**Purpose**: Generate backup reports in different formats

**Common Report Structure**:
- **ReportMetadata**: Generated timestamp, version, generator
- **BackupDetails**: Name, type, timestamp, duration, status
- **Paths**: Source, destination
- **Statistics**: Files backed up, sizes, compression ratio
- **Changes**: Modified/new/deleted files
- **Integrity**: State saved, previous backups verified, corrupted backups
- **SystemInfo**: Computer name, user, OS version, PowerShell version

#### 4.2 Protect-Report.ps1

**Purpose**: Digitally sign report with HMAC-SHA256

**Signature File**: `ReportPath.sig` (JSON)

**Signature Structure**:
```json
{
  "ReportFile": "backup_report.html",
  "Algorithm": "SHA256",
  "Hash": "A1B2C3D4...",
  "SignedAt": "2025-12-30T12:00:00Z",
  "SignedBy": "username@computername"
}
```

**Usage**: Allows tamper detection via `Confirm-ReportSignature`

#### 4.3 Confirm-ReportSignature.ps1

**Purpose**: Verify report hasn't been modified

**Verification**:
1. Load `.sig` file
2. Calculate HMAC-SHA256 from report and metadata with same secret key
3. Compare with expected hash from signature
4. Return validation result

#### 4.4 Get-ReportSigningKey.ps1

**Purpose**:  Retrieves the report signing key from Windows Credential Manager.

---

### 5. Restore Module

**Location**: `src/Modules/Restore/`

#### 5.1 Resolve-Backups.ps1

**Purpose**: Discover and normalize all backups in a directory

**Process**:
1. Call `Get-BackupCandidates` (finds folders + ZIPs)
2. For each candidate:
   - Extract metadata (via `Get-MetadataFromFolder` or `Get-MetadataFromZip`)
   - Parse timestamp (via `Convert-BackupTimestampToDateTime`)
   - Normalize BackupType to canonical values (Full/Incremental)
3. Return array of normalized backup objects

#### 5.2 Invoke-Restore.ps1

**Purpose**: Apply backup chain (full + incrementals) to restore directory

**Algorithm**:
```
1. Sort chain by timestamp (oldest first)
2. For each backup in chain:
   a. Copy all files from backup to restore directory (overwrite)
   b. If backup metadata contains DeletedFiles:
      - Remove those files from restore directory
3. Cleanup extracted temp folders (for ZIPs)
4. Remove .backup-metadata.json files from restore output
```

**Example Chain**:
```
Full (2025-12-25) → Incr (2025-12-26) → Incr (2025-12-27)
        ↓                    ↓                    ↓
    [100 files]         [+5 new]            [+3 new, -2 deleted]
                             ↓
                    Final Restore: 106 files
```

---

### 6. Retention Module

**Location**: `src/Modules/Retention/`

#### 6.1 Invoke-BackupRetention.ps1

**Purpose**: Delete backups older than retention period

**Safety Logic**:
```powershell
# Never delete ALL backups (protects against clock skew)
if ($backupsToDelete.Count -eq $allBackups.Count -and $allBackups.Count -gt 0) {
    Write-Log "SAFETY: Refusing to delete ALL backups"
    return
}
```

#### 6.2 Invoke-BackupCleanup.ps1

**Purpose**: Wrapper for retention cleanup via unified command interface

**Usage**: Called by `Invoke-FileGuardian -Action Cleanup -BackupName "..."`

**Configuration Priority**:
1. Explicit parameters (`-RetentionDays`, `-CleanupBackupDirectory`)
2. Backup-specific config (`ScheduledBackups[].RetentionDays`)
3. Global config (`BackupSettings.RetentionDays`)

---

### 7. Scheduling Module

**Location**: `src/Modules/Scheduling/`

#### 7.1 Register-BackupSchedule.ps1

**Purpose**: Register Windows Scheduled Tasks for automated backups

**Task Creation**:

For each enabled backup in config, creates **TWO tasks**:

**1. Backup Task** (`FileGuardian_BackupName`)
- **Action**: PowerShell command that imports module and calls `Invoke-FileGuardian`
- **Trigger**: Based on schedule (Daily/Weekly/Hourly)
- **Settings**: Start when available, allow on battery

**2. Cleanup Task** (`FileGuardian_Cleanup_BackupName`)
- **Action**: PowerShell command calling `Invoke-FileGuardian -Action Cleanup`
- **Trigger**: Event-based
- **Event Filter**: Only triggers when backup task finishes successfully

---

### 8. Configuration Module

**Location**: `src/Modules/Config/`

#### 8.1 Read-Config.ps1

**Purpose**: Load and parse `backup-config.json`

**Path Resolution**:
1. Explicit `-ConfigPath` parameter
2. `$env:FILEGUARDIAN_CONFIG_PATH` environment variable
3. Throws error if neither provided

**Validation**:
- File must exist
- File must be valid JSON
- File must not be empty

**Caching**: Result cached in `$script:FileGuardian_CachedConfig` to avoid repeated reads

**Config Structure**:
```json
{
  "GlobalSettings": {
    "LogDirectory": "...",
    "ReportOutputPath": "...",
    "ReportFormat": "JSON|HTML|CSV",
    "DefaultBackupType": "Full|Incremental"
  },
  "BackupSettings": {
    "DestinationPath": "...",
    "CompressBackups": true/false,
    "ExcludePatterns": ["*.tmp", "..."],
    "RetentionDays": 30
  },
  "ScheduledBackups": [
    {
      "Name": "...",
      "Enabled": true/false,
      "SourcePath": "...",
      "BackupPath": "...",
      "ReportOutputPath": "...",
      "BackupType": "Full|Incremental",
      "Schedule": {
        "Frequency": "Daily|Weekly|Hourly",
        "Time": "HH:mm",
        "DaysOfWeek": ["Monday", ...]
      },
      "CompressBackups": true/false,
      "ExcludePatterns": [...],
      "ReportFormat": "JSON|HTML|CSV",
      "RetentionDays": 30
    }
  ]
}
```

---

### 9. Logging Module

**Location**: `src/Modules/Logging/`

#### 9.1 Write-Log.ps1

**Purpose**: Centralized logging for all operations

**Log Levels**: Info, Warning, Error, Success

**Output Destinations**:
1. **Console**: Color-coded messages (Cyan/Yellow/Red/Green)
2. **File**: Daily log files `fileguardian_YYYYMMDD.log`

**Log Directory Priority**:
1. `GlobalSettings.LogDirectory` (from config)
2. `$env:ProgramData\FileGuardian\logs` (system-wide)
3. `$env:LOCALAPPDATA\FileGuardian\logs` (user-specific fallback)

**Log Format**:
```
[2025-12-30 12:00:00] [Info] Starting backup operation...
[2025-12-30 12:00:05] [Success] Backup completed: 42 files backed up
```

**Log Rotation**:
- Automatically removes logs older than 90 days
- Runs on each `Write-Log` call (low overhead)

> **Note**  
> If no log directory is specified, the default locations will be used:  
> - `%ProgramData%\FileGuardian\logs`  
> - `%LOCALAPPDATA%\FileGuardian\logs`
---

## Data Flow & State Management

### State Files

**Location**: `{BackupDestinationPath}/states/`

**Purpose**: Track file integrity and enable incremental backups

#### State File Types

1. **latest.json**
   - Current state after most recent backup
   - Used as baseline for next incremental backup

2. **prev.json**
   - Previous `latest.json` (rotated on each backup)
   - Enables "undo" or historical comparison

3. **BackupName.json**
   - Backup-specific state snapshot
   - Used for integrity verification of that specific backup

#### State Lifecycle

```
Initial Backup (Full):
  ├─► Calculate hashes for all source files
  ├─► Save as states/latest.json
  └─► Copy to states/BackupName_20251230_120000.json

First Incremental:
  ├─► Load states/latest.json (previous state)
  ├─► Calculate current hashes
  ├─► Compare: detect changes, new, deleted files
  ├─► Rotate: latest.json → prev.json
  ├─► Save new latest.json
  └─► Save states/BackupName_20251230_130000.json

Second Incremental:
  ├─► Load states/latest.json (from first incremental)
  └─► Repeat cycle...
```

### Backup Metadata Files

**Location**: Inside each backup folder/ZIP as `.backup-metadata.json`

**Purpose**: Self-documenting backups for restore operations

**Usage**:
- Restore operations use metadata to identify backup type and chain
- Integrity verification uses metadata to validate backup contents