BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:RestoreModulePath = Join-Path $ProjectRoot "src\Modules\Restore"
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"

    # Import Logging module dependency
    . (Join-Path $script:LoggingModulePath "Write-Log.ps1")

    # Dot-source all Restore module helpers/public functions
    Get-ChildItem -Path $script:RestoreModulePath -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }

    function script:New-RestoreBackupFolder {
        param($Path, $backupType = 'Full', $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss'))

        if (Test-Path $Path) { Remove-Item -Path $Path -Recurse -Force }
        New-Item -Path $Path -ItemType Directory -Force | Out-Null

        # create metadata
        $meta = @{
            BackupType = $backupType
            Timestamp = $timestamp
            Files = @()
        } | ConvertTo-Json -Depth 5

        $meta | Set-Content -Path (Join-Path $Path '.backup-metadata.json')

        # add a sample file
        "Test content" | Out-File (Join-Path $Path "sample.txt")
    }

    function script:New-RestoreBackupZip {
        param($FolderPath, $ZipPath, $backupType = 'Full', $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss'))

        # create a temporary folder which will be zipped
        if (Test-Path $FolderPath) { Remove-Item -Path $FolderPath -Recurse -Force }
        New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null

        $meta = @{
            BackupType = $backupType
            Timestamp = $timestamp
            Files = @()
        } | ConvertTo-Json -Depth 5
        $meta | Set-Content -Path (Join-Path $FolderPath '.backup-metadata.json')
        "Zip content" | Out-File (Join-Path $FolderPath "file-in-zip.txt")

        if (Test-Path $ZipPath) { Remove-Item -Path $ZipPath -Force }
        Compress-Archive -Path (Join-Path $FolderPath '*') -DestinationPath $ZipPath -Force
    }
}

Describe "Restore Module" {
    BeforeEach {
        $script:TestBackupRoot = Join-Path $TestDrive "RestoreBackups"
        $script:TestRestoreOutput = Join-Path $TestDrive "RestoreOutput"

        if (Test-Path $script:TestBackupRoot) { Remove-Item -Path $script:TestBackupRoot -Recurse -Force }
        New-Item -Path $script:TestBackupRoot -ItemType Directory | Out-Null

        if (Test-Path $script:TestRestoreOutput) { Remove-Item -Path $script:TestRestoreOutput -Recurse -Force }
    }

    AfterEach {
        if (Test-Path $script:TestBackupRoot) { Remove-Item -Path $script:TestBackupRoot -Recurse -Force }
        if (Test-Path $script:TestRestoreOutput) { Remove-Item -Path $script:TestRestoreOutput -Recurse -Force }
    }

    Context "Candidates and metadata" {
        It "Should return folders and zip files from Get-BackupCandidates" {
            $folder = Join-Path $script:TestBackupRoot 'BackupFolder'
            New-RestoreBackupFolder -Path $folder

            $zipFolder = Join-Path $script:TestBackupRoot 'ZipFolder'
            $zipPath = Join-Path $script:TestBackupRoot 'backup.zip'
            New-RestoreBackupZip -FolderPath $zipFolder -ZipPath $zipPath
            # remove temporary folder used to create the zip so only the zip remains as a candidate
            if (Test-Path $zipFolder) { Remove-Item -Path $zipFolder -Recurse -Force }

            $items = Get-BackupCandidates -BackupDirectory $script:TestBackupRoot
            $items | Should -Contain $folder
            $items | Should -Contain $zipPath
        }

        It "Should read metadata JSON from Get-MetadataFromFolder" {
            $folder = Join-Path $script:TestBackupRoot 'MetaFolder'
            New-RestoreBackupFolder -Path $folder -backupType 'Full'

            $meta = Get-MetadataFromFolder -FolderPath $folder
            $meta.BackupType | Should -Be 'Full'
            $meta.Timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should extract and return metadata from Get-MetadataFromZip" {
            $zipFolder = Join-Path $script:TestBackupRoot 'ZipMeta'
            $zipPath = Join-Path $script:TestBackupRoot 'metazip.zip'
            New-RestoreBackupZip -FolderPath $zipFolder -ZipPath $zipPath -backupType 'Incremental'
            if (Test-Path $zipFolder) { Remove-Item -Path $zipFolder -Recurse -Force }

            $info = Get-MetadataFromZip -ZipPath $zipPath
            $info | Should -Not -BeNullOrEmpty
            $info.ExtractPath | Should -Not -BeNullOrEmpty
            $info.Metadata.BackupType | Should -Be 'Incremental'
            Test-Path $info.ExtractPath | Should -BeTrue
            # cleanup extract path (function under test may also remove later)
            Remove-Item -Path $info.ExtractPath -Recurse -Force
        }
    }

    Context "Resolve and restore" {
        It "Should return normalized objects for folder and zip in Resolve-Backups" {
            $folder = Join-Path $script:TestBackupRoot 'ResolveFolder'
            New-RestoreBackupFolder -Path $folder -backupType 'Full'

            $zipFolder = Join-Path $script:TestBackupRoot 'ResolveZipTmp'
            $zipPath = Join-Path $script:TestBackupRoot 'resolve.zip'
            New-RestoreBackupZip -FolderPath $zipFolder -ZipPath $zipPath -backupType 'Incremental'
            if (Test-Path $zipFolder) { Remove-Item -Path $zipFolder -Recurse -Force }

            $resolved = Resolve-Backups -BackupDirectory $script:TestBackupRoot
            $resolved.Count | Should -Be 2
            $resolved | Where-Object { $_.IsZip } | Should -Not -BeNullOrEmpty
            $resolved | Where-Object { -not $_.IsZip } | Should -Not -BeNullOrEmpty
            $resolved | ForEach-Object { $_.Timestamp -is [DateTime] | Should -BeTrue }

            # Cleanup any extracted temporary folders created by Resolve-Backups to avoid leaving temp artifacts
            foreach ($r in $resolved | Where-Object { $_.IsZip }) {
                if ($r.ExtractPath -and (Test-Path $r.ExtractPath)) {
                    Remove-Item -Path $r.ExtractPath -Recurse -Force
                }
            }
        }

        It "Should apply backups into restore directory and remove metadata files with Invoke-Restore" {
            $folder = Join-Path $script:TestBackupRoot 'ApplyFolder'
            New-RestoreBackupFolder -Path $folder -backupType 'Full'

            $zipFolder = Join-Path $script:TestBackupRoot 'ApplyZipTmp'
            $zipPath = Join-Path $script:TestBackupRoot 'apply.zip'
            New-RestoreBackupZip -FolderPath $zipFolder -ZipPath $zipPath -backupType 'Incremental'
            if (Test-Path $zipFolder) { Remove-Item -Path $zipFolder -Recurse -Force }

            $resolved = Resolve-Backups -BackupDirectory $script:TestBackupRoot

            $result = Invoke-Restore -Chain $resolved -RestoreDirectory $script:TestRestoreOutput
            $result | Should -Be $true

            # ensure files copied
            Test-Path (Join-Path $script:TestRestoreOutput 'sample.txt') | Should -BeTrue
            Test-Path (Join-Path $script:TestRestoreOutput 'file-in-zip.txt') | Should -BeTrue

            # metadata files should not remain in restore output
            (Get-ChildItem -Path $script:TestRestoreOutput -Recurse -File | Where-Object { $_.Name -ieq '.backup-metadata.json' }).Count | Should -Be 0
        }
    }

    Context "Error handling and negative cases" {
        It "Should throw when backup directory is missing in Get-BackupCandidates" {
            { Get-BackupCandidates -BackupDirectory (Join-Path $TestDrive 'NonExistent') } | Should -Throw
        }

        It "Should throw when metadata file is missing in Get-MetadataFromFolder" {
            $bad = Join-Path $script:TestBackupRoot 'BadMeta'
            New-Item -Path $bad -ItemType Directory -Force | Out-Null
            { Get-MetadataFromFolder -FolderPath $bad } | Should -Throw
        }

        It "Should throw for missing or invalid zip in Get-MetadataFromZip" {
            $fake = Join-Path $script:TestBackupRoot 'notazip.zip'
            "not a zip" | Set-Content -Path $fake
            { Get-MetadataFromZip -ZipPath (Join-Path $script:TestBackupRoot 'doesnotexist.zip') } | Should -Throw
            { Get-MetadataFromZip -ZipPath $fake } | Should -Throw
        }

        It "Should throw when metadata misses required fields in Resolve-Backups" {
            $bad = Join-Path $script:TestBackupRoot 'BadFields'
            New-Item -Path $bad -ItemType Directory -Force | Out-Null
            # write metadata missing Timestamp
            @{ BackupType = 'Full' } | ConvertTo-Json | Set-Content -Path (Join-Path $bad '.backup-metadata.json')
            { Resolve-Backups -BackupDirectory $script:TestBackupRoot } | Should -Throw
        }

        It "Should throw when mandatory parameters are missing for Invoke-Restore" {
            { Invoke-Restore -Chain @() } | Should -Throw
            { Invoke-Restore -RestoreDirectory $script:TestRestoreOutput } | Should -Throw
        }
    }
}
