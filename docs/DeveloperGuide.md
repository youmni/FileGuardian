# FileGuardian — Developer Guide

This document explains the architecture, module responsibilities, development workflow, testing, and conventions used in the FileGuardian project. It is intended for contributors and maintainers who need to understand how the system is organized and how to extend or debug it.

**Quick links**
- Source entry: `src\FileGuardian.ps1`
- CLI entry/function: `Invoke-FileGuardian` (defined in `src\FileGuardian.ps1`)
- Scheduling: `src\Modules\Scheduling\Register-BackupSchedule.ps1`
- Backup modules: `src\Modules\Backup\*.ps1`
- Integrity modules: `src\Modules\Integrity\*.ps1`
- Reporting modules: `src\Modules\Reporting\*.ps1`
- Restore modules: `src\Modules\Restore\*.ps1`
- Logging: `src\Modules\Logging\Write-Log.ps1`
- Config: `config\backup-config.json`

## Architecture Overview

FileGuardian is structured as a thin top-level command (function) that dispatches to small, focused modules. The primary entry point is the `Invoke-FileGuardian` function in `src\FileGuardian.ps1`. That function parses parameters and routes work to modules that implement:

- Backup (full / incremental) — `src\Modules\Backup\*`
- Integrity state and verification — `src\Modules\Integrity\*`
- Reporting and signing — `src\Modules\Reporting\*`
- Scheduling and Windows Task registration — `src\Modules\Scheduling\Register-BackupSchedule.ps1`
- Restore logic — `src\Modules\Restore\*`
- Retention cleanup — `src\Modules\Backup\Invoke-RetentionCleanup.ps1`
- Logging helper — `src\Modules\Logging\Write-Log.ps1`

Design principles:
	- `Get-FileIntegrityHash.ps1`: canonical SHA256 file hashing and path normalization.
	- `Save-IntegrityState.ps1`: persist `latest.json`/`prev.json` state files used for incremental backups.
	- `Test-BackupIntegrity.ps1` & `Compare-BackupIntegrity.ps1`: verify backups against saved state and produce a verification summary.

## Main flow (high-level)

1. User or scheduler triggers `Invoke-FileGuardian` with an `-Action` (Backup, Verify, Report, Restore, Schedule, Cleanup).
2. `Invoke-FileGuardian` validates inputs and reads configuration as needed.
3. For backups:
	 - `Invoke-FullBackup` or `Invoke-IncrementalBackup` is called.
	 - Files are enumerated and integrity hashes are computed (`Get-FileIntegrityHash`).
	 - Backup artifacts (folder or compressed ZIP) are written and metadata saved (`Save-BackupMetadata`).
	 - An integrity state is stored (`Invoke-IntegrityStateSave`).
	 - A report is generated via `New-BackupReport` and output functions `Write-JsonReport` / `Write-HtmlReport` / `Write-CsvReport`.
	 - Reports are protected/signed with `Protect-Report`.
4. For verify/report/restore/cleanup actions, dedicated modules perform the work and return structured PSCustomObjects describing results.

## Module guide

Below are the major modules and their responsibilities (file paths are relative to repository root):

- `src\FileGuardian.ps1`
	- Top-level function `Invoke-FileGuardian` that implements the CLI surface and dispatch logic.
	- Imports nested modules from `src\Modules` at startup for local development.

- `src\Modules\Backup\` (core backup logic)
	- `Invoke-FullBackup.ps1`: performs full backups, creates metadata and reports.
	- `Invoke-IncrementalBackup.ps1`: computes changes since last state and writes incremental backups.
	- `Compress-Backup.ps1`: optional compression helper.
	- `Save-BackupMetadata.ps1`: write `.backup-metadata.json` and state files.
	- `Invoke-BackupRetention.ps1`: removes backups older than retention rules.
	- `Invoke-RetentionCleanup.ps1`: orchestration wrapper used by schedule cleanup tasks.

- `src\Modules\Integrity\` (integrity hashing and verification)
		 - `Get-FileIntegrityHash.ps1`: canonical SHA256 file hashing and path normalization.
		 - `Save-IntegrityState.ps1`: persist `latest.json`/`prev.json` state files used for incremental backups.
		 - `Test-BackupIntegrity.ps1` & `Compare-BackupIntegrity.ps1`: verify backups against saved state and produce a verification summary.

- `src\Modules\Reporting\` (report generation and signature)
	- `New-BackupReport.ps1`: builds report object.
	- `Write-JsonReport.ps1`, `Write-HtmlReport.ps1`, `Write-CsvReport.ps1`: output formats.
	- `Protect-Report.ps1`: signs reports and writes `.sig` files.
	- `Confirm-ReportSignature.ps1`: verify signature for a given report.

 Backup modules: `src\Modules\Backup\*.ps1`
 Integrity modules: `src\Modules\Integrity\*.ps1`
 Reporting modules: `src\Modules\Reporting\*.ps1`
 Restore modules: `src\Modules\Restore\*.ps1`
 Logging: `src\Modules\Logging\Write-Log.ps1`
 Scheduling and Windows Task registration — `src\Modules\Scheduling\Register-BackupSchedule.ps1`
 Retention cleanup — `src\Modules\Backup\Invoke-RetentionCleanup.ps1`
 Logging helper — `src\Modules\Logging\Write-Log.ps1`
 Small focused functions: each `*.ps1` exposes a single function representing one responsibility.
	 - `Invoke-FullBackup.ps1`: performs full backups, creates metadata and reports.
	 - `Invoke-IncrementalBackup.ps1`: computes changes since last state and writes incremental backups.
	 - `Compress-Backup.ps1`: optional compression helper.
	 - `Save-BackupMetadata.ps1`: write `.backup-metadata.json` and state files.
	 - `Invoke-BackupRetention.ps1`: removes backups older than retention rules.
	 - `Invoke-RetentionCleanup.ps1`: orchestration wrapper used by schedule cleanup tasks.
	 - `Get-FileIntegrityHash.ps1`: canonical SHA256 file hashing and path normalization.
	 - `Save-IntegrityState.ps1`: persist `latest.json`/`prev.json` state files used for incremental backups.
	 - `Test-BackupIntegrity.ps1` & `Compare-BackupIntegrity.ps1`: verify backups against saved state and produce a verification summary.
	 - `New-BackupReport.ps1`: builds report object.
	 - `Write-JsonReport.ps1`, `Write-HtmlReport.ps1`, `Write-CsvReport.ps1`: output formats.
 `src\Modules\Scheduling\Register-BackupSchedule.ps1`
 `src\Modules\Logging\Write-Log.ps1`
 Update `Initialize-BackupConfiguration.ps1` if defaults or mapping logic are required.
1. Follow the repository layout: add small focused `*.ps1` files in `src\Modules\<Area>`.
2. Export exactly one primary function per module file and name the function after the file (e.g., `Invoke-FullBackup` in `Invoke-FullBackup.ps1`).
 `src\Modules\Backup\Invoke-FullBackup.ps1` — full backup implementation
 `src\Modules\Backup\Invoke-IncrementalBackup.ps1` — incremental backup implementation
 `src\Modules\Integrity\Get-FileIntegrityHash.ps1` — hashing/normalization
 `src\Modules\Reporting\Write-JsonReport.ps1` — JSON output
 `src\Modules\Reporting\Protect-Report.ps1` — signing reports
 `src\Modules\Scheduling\Register-BackupSchedule.ps1` — schedule registration
 `src\Modules\Logging\Write-Log.ps1` — log helper
When adding fields:
- Update `Initialize-BackupConfiguration.ps1` if defaults or mapping logic are required.

## Scheduling

- Use `Invoke-FileGuardian -Action Schedule` to register scheduled tasks from `backup-config.json`.
- The scheduler module creates two tasks per configured backup:
	- `FileGuardian_<Name>` — runs backup.
	- `FileGuardian_Cleanup_<Name>` — runs cleanup and is triggered by the backup task completion event.
- The scheduled task action imports the module manifest and calls `Invoke-FileGuardian` with a parameter set. Splatting is used in code examples and safe command-building is used when generating the scheduled task arguments.

## Development workflow

1. Clone repository and open in PowerShell-capable editor (VS Code recommended).
2. During development you can dot-source the top-level script to load functions into session:

```powershell
. .\src\FileGuardian.ps1
Invoke-FileGuardian -Action Backup -SourcePath 'C:\MyData' -DestinationPath 'D:\Backups' -BackupName 'DevTest'
```

Or import the module (after creating a module manifest `FileGuardian.psd1`) and call `Invoke-FileGuardian`.

Tips:
- Use splatting for complex parameter sets when invoking `Invoke-FileGuardian` programmatically.
- Run verbose logging with `-Verbose` and/or set `$VerbosePreference` when debugging.

## Testing

- Unit tests: the repo contains Pester tests in the `tests\` folder. Run with:

```powershell
# Run all Pester tests
Invoke-Pester -Script .\tests -Output Detailed
```

- Static analysis: run PSScriptAnalyzer to verify style and common issues:

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path src -Recurse
```

## Contributing new features or modules

1. Follow the repository layout: add small focused `*.ps1` files in `src\Modules\<Area>`.
2. Export exactly one primary function per module file and name the function after the file (e.g., `Invoke-FullBackup` in `Invoke-FullBackup.ps1`).
3. Use `Write-Log` for internal messages instead of writing directly to the console.
4. Add Pester tests exercising the function's public behavior, and prefer returning structured objects (PSCustomObject) instead of unstructured text.

## Conventions and style

- Function names: Verb-Noun (PowerShell standard). Keep names descriptive and consistent.
- Parameter validation: prefer `[ValidateScript()]` checks and `[ValidateSet()]` for enums.
- Avoid brittle line-continuation backticks; use splatting or hashtables for parameter sets and `-Command` argument building for scheduled tasks.
- Use `Try/Catch` around external calls and log exceptions with `Write-Log -Level Error`.

## Debugging common issues

- "Task not registered" — ensure you run the `Schedule` action as Administrator. The scheduler code checks for admin privileges.
- "No backups found" on restore — verify the backup directory structure and `latest.json` state files.
- "Report signature invalid" — check report `.sig` file presence and that `Protect-Report` was executed successfully when generating the report.

## Automation & CI

- Recommended CI checks:
	- Run `Invoke-ScriptAnalyzer` on `src`.
	- Run `Invoke-Pester` to execute tests.
	- Lint docs with a Markdown linter if desired.

## Useful developer commands

```powershell
# Load the module during development
. .\src\FileGuardian.ps1

# Run a backup quickly using splatting
$params = @{
	Action = 'Backup'
	SourcePath = 'C:\Temp\Data'
	DestinationPath = 'D:\Backups\Dev'
	BackupName = 'DevQuick'
	ReportFormat = 'JSON'
	Compress = $true
}
Invoke-FileGuardian @params

# Register scheduled tasks from config (Admin)
Invoke-FileGuardian -Action Schedule -ConfigPath '.\config\backup-config.json'

# Run tests
Invoke-Pester -Script .\tests -Output Detailed

# Static analysis
Invoke-ScriptAnalyzer -Path src -Recurse
```

## File map (quick)
- `src\FileGuardian.ps1` — CLI entry and dispatcher
 - `src\Modules\Backup\Invoke-FullBackup.ps1` — full backup implementation
 - `src\Modules\Backup\Invoke-IncrementalBackup.ps1` — incremental backup implementation
 - `src\Modules\Integrity\Get-FileIntegrityHash.ps1` — hashing/normalization
 - `src\Modules\Reporting\Write-JsonReport.ps1` — JSON output
 - `src\Modules\Reporting\Protect-Report.ps1` — signing reports
 - `src\Modules\Scheduling\Register-BackupSchedule.ps1` — schedule registration
 - `src\Modules\Restore\Invoke-Restore.ps1` — restore orchestration
 - `src\Modules\Logging\Write-Log.ps1` — log helper

## Final notes

Keep functions small and testable. When in doubt, add a Pester test and a short docstring describing the function inputs and expected outputs.