# FileGuardian

An automated backup system with cryptographic integrity verification for Windows environments.

## Overview

FileGuardian is a robust, modular PowerShell tool designed to automate file backups while ensuring data integrity through cryptographic hash verification. The system helps prevent data loss and undetected file corruption by validating every backup operation.


## Features

## Core Functionality (MVP)

- [x] **Automated Backups**  
  Supports both full and incremental backup modes

- [x] **Scheduled Execution**  
  Integration with external schedulers (e.g. Windows Task Scheduler, cron)

- [x] **Comprehensive Logging**  
  Detailed action logging with timestamps and error tracking

- [x] **JSON Reporting**  
  Structured reports including processed files, detected changes, and errors

- [x] **Integrity Verification**  
  File integrity validation using hash comparison between source and destination

- [x] **Compression**  
  Optional compression of backup data

- [x] **Digital Signatures**  
  Cryptographic signing of backup reports to ensure authenticity and integrity


## Optional Enhancements

### Backup Strategies
- [ ] Differential backups  
- [ ] Mirror backups  
- [ ] Versioned backup history  

### Storage Targets
- [ ] Network Attached Storage (NAS)  
- [ ] Cloud storage providers  
- [ ] SFTP / remote servers  

### User Experience
- [ ] Text-based User Interface (TUI)  
- [ ] Configuration validation and dry-run mode  

### Notifications & Reporting
- [ ] Email notifications for errors or integrity issues  
- [x] Additional report formats (CSV, HTML)  

## Reports

The system generates comprehensive JSON reports containing:
- Number of processed files
- New, modified, or deleted files
- Hash verification results
- Errors or integrity mismatches
- Execution timestamps

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **UserGuide.md** - End-user instructions and examples

## Authors
- [@Youmni Malha](https://github.com/Youmni)