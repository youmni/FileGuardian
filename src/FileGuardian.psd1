@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'FileGuardian.ps1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'Youmni Malha'

    # Company or vendor of this module
    CompanyName = ''

    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'FileGuardian - Automated backup system with cryptographic integrity verification for Windows environments.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Nested modules to load
    NestedModules = @(
        'Modules\Logging\Write-Log.psm1',
        'Modules\Config\Read-Config.psm1',
        'Modules\Backup\Invoke-FullBackup.psm1',
        'Modules\Backup\Invoke-IncrementalBackup.psm1',
        'Modules\Backup\Invoke-BackupRetention.psm1',
        'Modules\Backup\Compress-Backup.psm1',
        'Modules\Integrity\Test-BackupIntegrity.psm1',
        'Modules\Integrity\Get-FileIntegrityHash.psm1',
        'Modules\Integrity\Save-IntegrityState.psm1',
        'Modules\Reporting\Write-JsonReport.psm1',
        'Modules\Reporting\Protect-Report.psm1',
        'Modules\Reporting\Confirm-ReportSignature.psm1'
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    # Invoke-FileGuardian is the main public API; other exports are for internal use by FileGuardian.ps1 and tooling scripts
    FunctionsToExport = @(
        'Invoke-FileGuardian',
        'Write-Log'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Backup', 'Integrity', 'Hash', 'Verification', 'FileGuardian', 'Automation', 'Windows')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release with unified command interface.'
        }
    }
}
