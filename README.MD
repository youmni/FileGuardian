# FileGuardian

An automated backup system with cryptographic integrity verification for Windows environments.

## Overview

FileGuardian is a robust, modular PowerShell tool designed to automate file backups while ensuring data integrity through cryptographic hash verification. The system helps prevent data loss and undetected file corruption by validating every backup operation.

## Project Structure

```
FileGuardian/
│
├── src/
│   ├── FileGuardian.ps1
│   ├── Modules/
│   │   ├── Backup/
│   │   │   ├── Invoke-FullBackup.psm1
│   │   │   ├── Invoke-IncrementalBackup.psm1
│   │   │   ├── Invoke-DifferentialBackup.psm1
│   │   │   └── Compress-Backup.psm1
│   │   │
│   │   ├── Integrity/
│   │   │   ├── Test-FileHash.psm1
│   │   │   └── Compare-BackupIntegrity.psm1
│   │   │
│   │   ├── Reporting/
│   │   │   ├── Write-JsonReport.psm1
│   │   │   ├── Write-HtmlReport.psm1
│   │   │   └── Sign-Report.psm1
│   │   │
│   │   ├── Logging/
│   │   │   └── Write-Log.psm1
│   │   │
│   │   ├── Config/
│   │   │   └── Read-Config.psm1
│   │   │
│   │   ├── Notifications/
│   │   │   └── Send-EmailNotification.psm1
│   │   │
│   │   └── StorageProviders/
│   │       ├── LocalStorage.psm1
│   │       ├── NASStorage.psm1
│   │       ├── SFTPStorage.psm1
│   │       └── CloudStorage.psm1
│
├── config/
│   ├── backup-config.json
│   └── scheduler-task.xml
│
├── reports/
│   └── (auto-generated reports)
│
├── logs/
│   └── (auto-generated logs)
│
├── tests/
│   ├── Backup.Tests.ps1
│   ├── Integrity.Tests.ps1
│   ├── Reporting.Tests.ps1
│   ├── Logging.Tests.ps1
│   └── Config.Tests.ps1
│
├── docs/
│   ├── Requirements.md
│   ├── DesignDocument.md
│   ├── UserGuide.md
│   └── DeveloperGuide.md
│
├── tools/
│   ├── Install-Dependencies.ps1
│   └── Register-ScheduledTask.ps1
│
├── Start-FileGuardian.ps1  # Main entry point wrapper script
└── README.md
```

## Features

### Core Functionality (MVP)
- **Automated Backups**: Supports both full and incremental backup modes
- **Integrity Verification**: Hash comparison between source and destination files
- **JSON Reporting**: Detailed reports including processed files, changes, and errors
- **Comprehensive Logging**: Action logging with timestamps and error tracking
- **Digital Signatures**: Backup reports can be digitally signed
- **Compression**: Optional backup compression
- **Scheduled Execution**: Integration with Windows Task Scheduler

### Optional Enhancements
- Email notifications for errors or integrity issues
- Text-based User Interface (TUI)
- Version control for backup history
- Additional backup types (mirror, differential)
- Extended storage targets (NAS, cloud, SFTP)
- Multiple report formats (CSV, HTML)

## Architecture

The tool is built using a modular architecture organized into specialized modules:

### Core Modules

**Backup Module** (`src/Modules/Backup/`)
- `Invoke-FullBackup.psm1` - Complete backup of all files
- `Invoke-IncrementalBackup.psm1` - Backup only changed files since last backup
- `Invoke-DifferentialBackup.psm1` - Backup changed files since last full backup
- `Compress-Backup.psm1` - Compression functionality

**Integrity Module** (`src/Modules/Integrity/`)
- `Test-FileHash.psm1` - Cryptographic hash generation and validation
- `Compare-BackupIntegrity.psm1` - Source and backup comparison

**Reporting Module** (`src/Modules/Reporting/`)
- `Write-JsonReport.psm1` - JSON format reports
- `Write-HtmlReport.psm1` - HTML format reports
- `Sign-Report.psm1` - Digital signature for reports

**Logging Module** (`src/Modules/Logging/`)
- `Write-Log.psm1` - Centralized logging with timestamps

**Configuration Module** (`src/Modules/Config/`)
- `Read-Config.psm1` - Configuration file parsing and validation

**Notifications Module** (`src/Modules/Notifications/`)
- `Send-EmailNotification.psm1` - Email alerts for errors and issues

**Storage Providers** (`src/Modules/StorageProviders/`)
- `LocalStorage.psm1` - Local filesystem operations
- `NASStorage.psm1` - Network-attached storage support
- `SFTPStorage.psm1` - Secure FTP transfers
- `CloudStorage.psm1` - Cloud storage integration

Each module is independent and reusable, ensuring maintainability and extensibility.

## Reports

The system generates comprehensive JSON reports containing:
- Number of processed files
- New, modified, or deleted files
- Hash verification results
- Errors or integrity mismatches
- Execution timestamps

## Best Practices

- Clear function naming with parameter validation
- Get-Help compatible documentation for all functions
- Consistent error handling and logging
- Modular code organization
- External configuration storage

## Problem Statement

Many Windows environments rely on manual backup processes or basic scripts without integrity verification. This leads to risks including:
- Human errors
- Incomplete copies
- Undetected file corruption
- Overwriting of corrupted files

While tools like Robocopy and Windows Backup exist, they lack automatic validation, consistent logging, and integration with broader management processes.

## Project Goals

Develop a PowerShell-based solution that:
- Automates backup operations on scheduled or manual basis
- Verifies file integrity using cryptographic hashes
- Provides transparent reporting and logging
- Integrates with existing Windows infrastructure
- Prevents data loss and undetected corruption

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **Requirements.md** - Detailed system and functional requirements
- **DesignDocument.md** - Architecture and design decisions
- **UserGuide.md** - End-user instructions and examples
- **DeveloperGuide.md** - Contributing and development guidelines

## Authors
- [@Youmni Malha](https://github.com/Youmni)