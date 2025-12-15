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

### Notifications & Reporting
- [ ] Email notifications for errors or integrity issues  
- [x] Additional report formats (CSV, HTML)  

## Documentation

For detailed usage instructions, configuration options, and examples, please refer to:

**[UserGuide.md](docs/UserGuide.md)** - Complete user documentation with examples

## Author
- [@Youmni Malha](https://github.com/Youmni)