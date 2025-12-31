# FileGuardian - Technical Architecture Documentation

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Project Structure](#project-structure)
3. [Architecture Design](#architecture-design)
4. [Module Breakdown](#module-breakdown)
5. [Data Flow & State Management](#data-flow--state-management)
6. [Configuration System](#configuration-system)
7. [Scheduling Architecture](#scheduling-architecture)
8. [Integrity Verification System](#integrity-verification-system)
9. [Testing Infrastructure](#testing-infrastructure)
10. [Deployment & Installation](#deployment--installation)
11. [Extension Points](#extension-points)
12. [Troubleshooting Guide](#troubleshooting-guide)

---

## System Overview

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Runtime** | PowerShell | 5.1+ | Cross-compatible scripting environment |
| **Module System** | PowerShell Module Manifest | .psd1 / .psm1 | Modular architecture with nested modules |
| **Cryptography** | .NET SHA256 | Framework 4.x+ | File integrity verification |
| **Compression** | .NET Compression | Framework 4.x+ | ZIP archive creation |
| **Scheduler** | Windows Task Scheduler | Win10/Server 2016+ | Automated backup execution |
| **Testing** | Pester | 5.0+ | Unit and integration testing |
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
│   └── backup-config.json                # Central configuration file
│
├── docs/
│   ├── UserGuide.md                      # End-user documentation
│   ├── DeveloperGuide.md                 # Developer documentation
│   └── DesignDocument.md                 # Architecture & design decisions
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
├── logs/                                 # Runtime logs (auto-created)
├── reports/                              # Generated reports (auto-created)
├── backups/                              # Default backup destination (configurable)
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

### Design Patterns

1. **Command Pattern**: `Invoke-FileGuardian -Action` routes to appropriate handlers
2. **Strategy Pattern**: Backup types (Full/Incremental) implement common interface
3. **Facade Pattern**: Module wrapper functions hide internal complexity
4. **Observer Pattern**: Event-driven cleanup tasks triggered by backup completion

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
4. Compress to ZIP (optional, via `Compress-Backup`)
5. Save integrity state (`Invoke-IntegrityStateSave`)
6. Verify previous backups (`Test-PreviousBackups`)
7. Generate report (`New-BackupReport`)

**Output**: PSCustomObject with:
- `Type`, `BackupName`, `Timestamp`, `FilesBackedUp`, `TotalSizeMB`
- `Compressed`, `CompressedSizeMB`, `CompressionRatio` (if compressed)
- `IntegrityStateSaved`, `ReportPath`, `ReportSigned`

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

**Output**: Same structure as FullBackup + `FilesChanged`, `FilesNew`, `FilesDeleted`

#### 2.3 Compress-Backup.ps1

**Purpose**: Create ZIP archive from backup folder

**Parameters**:
- `-SourcePath`: Directory to compress
- `-DestinationPath`: ZIP file path
- `-CompressionLevel`: Optimal | Fastest | NoCompression
- `-RemoveSource`: Delete source after successful compression

**Algorithm**:
```powershell
Compress-Archive -Path "$SourcePath\*" -DestinationPath $DestinationPath -Force
```

**Safety**: Only removes source if compression succeeds (`$result.Success -eq $true`)

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
1. **Parallel Processing**: Uses runspace pool (max = CPU cores)
2. **Smart Caching**: Reuses hashes for unchanged files (based on LastWriteTime + Size)
3. **Consistent Paths**: Normalizes relative paths via `Get-ConsistentRelativePath`

**Parameters**:
- `-Path`: File or directory
- `-Recurse`: Process subdirectories
- `-StateDirectory`: Load `latest.json` for cache lookup
- `-Algorithm`: SHA256 | SHA1 | MD5
- `-MaxParallelJobs`: Default = CPU cores

**Output**: Array of PSCustomObject:
```powershell
@{
    Path = "C:\Source\file.txt"
    RelativePath = "file.txt"
    Hash = "A1B2C3..."
    Algorithm = "SHA256"
    Size = 1024
    LastWriteTime = "2025-12-30 12:00:00.000"
}
```

**Performance**: ~10x faster than sequential hashing for large file sets

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
      "RelativePath": "file.txt",
      "Hash": "A1B2C3...",
      "Algorithm": "SHA256",
      "Size": 1024,
      "LastWriteTime": "2025-12-30 12:00:00.000"
    }
  ]
}
```

**Optional**: Saves backup-specific state as `states/BackupName.json`

#### 3.3 Test-BackupIntegrity.ps1

**Purpose**: Verify backup files match saved state

**Process**:
1. Load state file (`states/BackupName.json` or `states/latest.json`)
2. Extract ZIP to temp folder if backup is compressed
3. Calculate current hashes for all files in backup
4. Compare with expected hashes from state
5. Categorize results: Verified, Corrupted, Missing, Extra

**Output**:
```powershell
@{
    BackupPath = "D:\Backups\..."
    IsIntact = $true
    Verified = @(...)      // Files with matching hashes
    Corrupted = @(...)     // Files with mismatched hashes
    Missing = @(...)       // Files in state but not in backup
    Extra = @(...)         // Files in backup but not in state
    Summary = @{
        VerifiedCount = 42
        CorruptedCount = 0
        MissingCount = 0
        ExtraCount = 0
    }
}
```

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
- **Changes**: Modified/new/deleted files (incremental only)
- **Integrity**: State saved, previous backups verified, corrupted backups
- **SystemInfo**: Computer name, user, OS version, PowerShell version

**HTML Report Features**:
- Modern gradient design with CSS styling
- Responsive layout
- Color-coded status indicators
- Corruption warnings highlighted

**Path Logic**:
```powershell
# If ReportPath is directory or not specified
if ((Test-Path $ReportPath -PathType Container) -or (-not [Path]::HasExtension($ReportPath))) {
    # Auto-generate filename: BackupName_YYYYMMDD_HHMMSS_report.{ext}
}
```

#### 4.2 Protect-Report.ps1

**Purpose**: Digitally sign report with SHA256 hash

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
2. Calculate current hash of report
3. Compare with expected hash from signature
4. Return validation result

**Output**: PSCustomObject with `IsValid`, `ExpectedHash`, `ActualHash`

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

**Output**:
```powershell
@(
    @{
        Path = "D:\Backups\Full_20251225_120000"
        IsZip = $false
        ExtractPath = $null
        Metadata = @{ BackupType = "Full"; Timestamp = "20251225_120000"; ... }
        Timestamp = [DateTime] "2025-12-25 12:00:00"
    },
    @{
        Path = "D:\Backups\Incr_20251226_120000.zip"
        IsZip = $true
        ExtractPath = "C:\Temp\..."
        Metadata = @{ BackupType = "Incremental"; ... }
        Timestamp = [DateTime] "2025-12-26 12:00:00"
    }
)
```

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

**Safety Checks**:
- Validates restore directory is writable
- Ensures deleted paths stay within restore directory (no path traversal)

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

**Parameters**:
- `-BackupDirectory`: Directory containing backups
- `-RetentionDays`: Age threshold (e.g., 30)
- `-BackupName`: Optional filter pattern

**Safety Logic**:
```powershell
# Never delete ALL backups (protects against clock skew)
if ($backupsToDelete.Count -eq $allBackups.Count -and $allBackups.Count -gt 0) {
    Write-Log "SAFETY: Refusing to delete ALL backups"
    return
}
```

**Operations**:
1. Find all backup folders/ZIPs in directory
2. Filter by BackupName pattern (if provided)
3. Check CreationTime against cutoff date
4. Delete old backups
5. Clean orphaned state files (states without corresponding backups)
6. **Never** delete `latest.json` or `prev.json`

**Output**: PSCustomObject with `DeletedCount`, `FreedSpaceMB`, `CutoffDate`

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
- **Principal**: SYSTEM account (runs without user login)
- **Settings**: Start when available, wake to run, allow on battery

**Command Structure**:
```powershell
$command = "Import-Module '$modulePath'; Invoke-FileGuardian -Action Backup -SourcePath '...' -BackupName '...' ..."
$argumentString = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
```

**2. Cleanup Task** (`FileGuardian_Cleanup_BackupName`)
- **Action**: PowerShell command calling `Invoke-FileGuardian -Action Cleanup`
- **Trigger**: Event-based (EventID 102 = backup task completed)
- **Event Filter**: Only triggers when backup task finishes successfully

**Event Subscription**:
```xml
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-TaskScheduler/Operational">
    <Select>
      *[System[(EventID=102)]] and 
      *[EventData[Data[@Name='TaskName']='\FileGuardian_BackupName']]
    </Select>
  </Query>
</QueryList>
```

**Removal**:
```powershell
Invoke-FileGuardian -Action Schedule -Remove  # Remove all tasks
Invoke-FileGuardian -Action Schedule -BackupName "..." -Remove  # Remove specific
```

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

**Thread Safety**: Uses `Out-File -Append` for concurrent write safety

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
- Metadata excluded from hash calculations (self-referential)