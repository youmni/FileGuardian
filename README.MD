# FileGuardian

**Automated backup system with cryptographic integrity verification for Windows environments**

---

## Overview

FileGuardian is a robust, modular PowerShell-based backup solution designed to automate file backups while ensuring data integrity through SHA256 cryptographic verification. The system helps prevent data loss and undetected file corruption by validating every backup operation and maintaining detailed audit trails through digitally signed reports.

FileGuardian offers flexible backup strategies, automated scheduling via Windows Task Scheduler and comprehensive reporting capabilities—all through a unified command-line interface.

---

## Features

### Core Capabilities

- **Multiple Backup Strategies**  
  - Full backups: Complete snapshots of source directories
  - Incremental backups: Efficient delta-based backups tracking only changed files
  - Automated fallback: Incremental operations automatically perform full backups when no baseline exists

- **Cryptographic Integrity Verification**  
  - SHA256 hash-based file validation
  - State tracking with `latest.json` and `prev.json` for change detection
  - Automatic corruption detection across all backup operations
  - Verification of previous backups during each backup cycle

- **Automated Scheduling**  
  - Integration with Windows Task Scheduler
  - Event-driven retention cleanup (executes automatically after successful backups)
  - Flexible scheduling: daily, weekly, hourly frequencies
  - Runs as SYSTEM account for reliable background execution

- **Comprehensive Reporting**  
  - Multiple output formats: JSON, HTML or CSV
  - Digital signatures (SHA256) for tamper detection
  - Detailed backup statistics and change summaries
  - Previous backup verification results included in reports

- **Optional Data Compression**  
  - ZIP archive creation with configurable compression levels
  - Compression ratio tracking
  - Space-saving for long-term storage

- **Intelligent Retention Management**  
  - Configurable retention periods per backup
  - Safe deletion logic (prevents accidental removal of all backups)

- **Restore Capabilities**  
  - Restore from full and incremental backup chains
  - Support for both compressed (ZIP) and uncompressed backups
  - Automatic deletion application for incremental restores
  - Metadata validation during restore operations

### Advanced Features

- **Exclusion Patterns**: Filter files using glob patterns (e.g., `*.tmp`, `node_modules/**`)
- **Parallel Hashing**: Multi-threaded file integrity calculation for improved performance
- **State Caching**: Smart hash reuse for unchanged files to optimize incremental operations
- **Detailed Logging**: Comprehensive timestamped logs with automatic rotation
- **Backup Verification**: Validate any backup's integrity against saved state
- **Report Signature Verification**: Confirm report authenticity via `.sig` files

---

## Installation

### Prerequisites

- **Operating System**: Windows 11
- **PowerShell**: Version 5.1 or later
- **Permissions**: Administrator rights (required for scheduled task registration)
- **Disk Space**: Sufficient storage for source data + backups

### Quick Start

1. **Clone the repository**
   ```powershell
   git clone https://github.com/Youmni/FileGuardian.git
   cd FileGuardian
   ```

2. **Set configuration path** (optional - recommended for scheduled tasks)
   ```powershell
   # Set environment variable to absolute path of your config file
   [Environment]::SetEnvironmentVariable('FILEGUARDIAN_CONFIG_PATH', <PATH>, 'User')
   ```
---

## Documentation

Comprehensive guides are available in the `docs/` directory:

- **[UserGuide.md](docs/UserGuide.md)** - Complete usage documentation with examples for all operations (Backup, Verify, Report, Restore, Schedule and  Cleanup)
- **[DeveloperGuide.md](docs/DeveloperGuide.md)** - System Overview, Project Structure, Architecture Design, Module Breakdown, Data Flow & State Management 

---

## Tech Stack

**Core Technologies:**
- PowerShell 5.1+
- Windows Credential Manager
- Windows Task Scheduler
- Pester

---

## Sources
- [Project Structure](https://chatgpt.com/share/6955997b-37d0-8007-8a27-72da58a47fd7)
- [MVP Approach](https://chatgpt.com/share/695597dd-da1c-8007-96ac-03d807df2617)
- [Better Hashing Approach](https://claude.ai/share/e62c59dc-6833-476e-993d-2ee6c99516b4)
- [Temp Cleanup](https://claude.ai/share/2df9cb6c-f4b6-4e75-95b4-011bac1fa85a)
- [AI Project Suggestions](https://claude.ai/share/ac685a0b-7423-4df4-a592-ba7ea9693595)
- [Refactor Config](https://claude.ai/share/7bb71e52-3a55-435f-a236-95dd8c8f89fb)
- [Cache & Parallel Hashing](https://claude.ai/share/79108519-e70b-4de7-9118-3056412ab1c8)
- [Incremental Backup Deletion Problem](https://claude.ai/share/aaffffca-450c-4ecc-9cd6-152597d87497)
- [Architecture Documentation](https://claude.ai/share/273d9edb-49d2-4992-999f-2f6152a4357f)
- [Powershell Commands](https://netwrix.com/en/resources/blog/powershell-commands-cheat-sheet/)
- [The slides from 'System automation & scripting'](https://bamaflexweb.ehb.be/BMFUIDetailxOLOD.aspx?a=166508&b=5&c=1)
- [HMACSHA256](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.hmacsha256?view=net-10.0)
- [Example HMACSHA256](https://asecuritysite.com/powershell/enc06)
- [Scheduled Tasks](https://www.pdq.com/blog/scheduled-tasks-in-powershell/)
- [Backup Video](https://youtu.be/aYGdEDZHo60?si=ogV4PERLTwCUqMDt)
- [Backups Explanation](https://www.acronis.com/en/blog/posts/incremental-differential-backups/)
- [Powershell Documentation](https://learn.microsoft.com/en-us/powershell/)
- [Manifest Documentation](https://learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest?view=powershell-7.5)
- [Pester Documentation](https://pester.dev/docs/quick-start)
- [CI Workflow](https://docs.github.com/en/actions/tutorials/build-and-test-code/powershell)
- 
---

## Testing

FileGuardian includes comprehensive test coverage using Pester.

**CI/CD:**  
Automated testing runs via GitHub Actions on every push to `feature/*` and `fix/*` branches, with results published as test artifacts.

---

## Author

**Youmni Malha**  
[@Youmni](https://github.com/Youmni)