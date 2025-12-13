BeforeAll {
    # Import required modules
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"
    $script:IntegrityModulePath = Join-Path $ProjectRoot "src\Modules\Integrity"
    
    # Import Logging module first (dependency)
    Import-Module (Join-Path $script:LoggingModulePath "Write-Log.psm1") -Force
    
    # Import Integrity modules
    Import-Module (Join-Path $script:IntegrityModulePath "Get-FileIntegrityHash.psm1") -Force
    Import-Module (Join-Path $script:IntegrityModulePath "Save-IntegrityState.psm1") -Force
    Import-Module (Join-Path $script:IntegrityModulePath "Compare-BackupIntegrity.psm1") -Force
    Import-Module (Join-Path $script:IntegrityModulePath "Test-BackupIntegrity.psm1") -Force
}

Describe "Get-FileIntegrityHash" {
    BeforeAll {
        # Create test data
        $script:testDataPath = Join-Path $TestDrive "IntegrityTestData"
        New-Item -Path $script:testDataPath -ItemType Directory | Out-Null
        
        "Test content 1" | Out-File (Join-Path $script:testDataPath "file1.txt")
        "Test content 2" | Out-File (Join-Path $script:testDataPath "file2.txt")
        
        $subFolder = Join-Path $script:testDataPath "subfolder"
        New-Item -Path $subFolder -ItemType Directory | Out-Null
        "Nested content" | Out-File (Join-Path $subFolder "nested.txt")
    }
    
    Context "Single file hashing" {
        It "Should hash a single file" {
            $file = Join-Path $script:testDataPath "file1.txt"
            $result = Get-FileIntegrityHash -Path $file
            
            $result | Should -Not -BeNullOrEmpty
            $result.Hash | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be "SHA256"
            $result.Size | Should -BeGreaterThan 0
        }
        
        It "Should return correct properties" {
            $file = Join-Path $script:testDataPath "file1.txt"
            $result = Get-FileIntegrityHash -Path $file
            
            $result.Path | Should -Be $file
            $result.RelativePath | Should -Not -BeNullOrEmpty
            $result.LastWriteTime | Should -Not -BeNullOrEmpty
        }
        
        It "Should support different algorithms" {
            $file = Join-Path $script:testDataPath "file1.txt"
            
            $sha256 = Get-FileIntegrityHash -Path $file -Algorithm SHA256
            $sha1 = Get-FileIntegrityHash -Path $file -Algorithm SHA1
            $md5 = Get-FileIntegrityHash -Path $file -Algorithm MD5
            
            $sha256.Algorithm | Should -Be "SHA256"
            $sha1.Algorithm | Should -Be "SHA1"
            $md5.Algorithm | Should -Be "MD5"
            
            $sha256.Hash | Should -Not -Be $sha1.Hash
        }
    }
    
    Context "Directory hashing" {
        It "Should hash all files in directory without recursion" {
            $result = Get-FileIntegrityHash -Path $script:testDataPath
            
            $result.Count | Should -Be 2
            $result.RelativePath | Should -Contain "file1.txt"
            $result.RelativePath | Should -Contain "file2.txt"
        }
        
        It "Should hash all files recursively" {
            $result = Get-FileIntegrityHash -Path $script:testDataPath -Recurse
            
            $result.Count | Should -Be 3
            $result.RelativePath | Should -Contain "file1.txt"
            $result.RelativePath | Should -Contain "file2.txt"
            $result.RelativePath | Should -Contain "subfolder\nested.txt"
        }
    }
    
    Context "Error handling" {
        It "Should throw on non-existent path" {
            { Get-FileIntegrityHash -Path "C:\NonExistent\path.txt" } | Should -Throw
        }
    }
}

Describe "Save-IntegrityState" {
    BeforeAll {
        # Create test data
        $script:sourceData = Join-Path $TestDrive "SourceData"
        New-Item -Path $script:sourceData -ItemType Directory | Out-Null
        
        "Source file 1" | Out-File (Join-Path $script:sourceData "source1.txt")
        "Source file 2" | Out-File (Join-Path $script:sourceData "source2.txt")
        
        $script:stateDir = Join-Path $TestDrive "states"
    }
    
    Context "State creation" {
        It "Should create state directory if not exists" {
            Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
            
            Test-Path $script:stateDir | Should -Be $true
        }
        
        It "Should create latest.json file" {
            Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
            
            $latestFile = Join-Path $script:stateDir "latest.json"
            Test-Path $latestFile | Should -Be $true
        }
        
        It "Should contain valid JSON structure" {
            Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
            
            $latestFile = Join-Path $script:stateDir "latest.json"
            $state = Get-Content $latestFile -Raw | ConvertFrom-Json
            
            $state.Timestamp | Should -Not -BeNullOrEmpty
            $state.SourcePath | Should -Not -BeNullOrEmpty
            $state.FileCount | Should -Be 2
            $state.Files | Should -HaveCount 2
        }
        
        It "Should include file hashes" {
            Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
            
            $latestFile = Join-Path $script:stateDir "latest.json"
            $state = Get-Content $latestFile -Raw | ConvertFrom-Json
            
            $state.Files[0].Hash | Should -Not -BeNullOrEmpty
            $state.Files[0].Algorithm | Should -Be "SHA256"
            $state.Files[0].Size | Should -BeGreaterThan 0
        }
    }
    
    Context "State rotation" {
        It "Should rotate latest to prev" {
            # First save
            Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
            Start-Sleep -Milliseconds 100
            
            # Second save
            Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
            
            $prevFile = Join-Path $script:stateDir "prev.json"
            Test-Path $prevFile | Should -Be $true
        }
        
        It "Should have different timestamps after rotation" {
            $latestFile = Join-Path $script:stateDir "latest.json"
            $prevFile = Join-Path $script:stateDir "prev.json"
            
            $latest = Get-Content $latestFile -Raw | ConvertFrom-Json
            $prev = Get-Content $prevFile -Raw | ConvertFrom-Json
            
            $latest.Timestamp | Should -Not -Be $prev.Timestamp
        }
    }
}

Describe "Compare-BackupIntegrity" {
    BeforeAll {
        # Create test data
        $script:sourceData = Join-Path $TestDrive "CompareSource"
        New-Item -Path $script:sourceData -ItemType Directory | Out-Null
        
        "File A" | Out-File (Join-Path $script:sourceData "fileA.txt")
        "File B" | Out-File (Join-Path $script:sourceData "fileB.txt")
        
        $script:stateDir = Join-Path $TestDrive "CompareStates"
        
        # Create first state
        Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
        Start-Sleep -Milliseconds 100
        
        # Modify data
        "Modified File A" | Out-File (Join-Path $script:sourceData "fileA.txt")
        "File C" | Out-File (Join-Path $script:sourceData "fileC.txt")
        Remove-Item (Join-Path $script:sourceData "fileB.txt")
        
        # Create second state
        Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
    }
    
    Context "Change detection" {
        It "Should detect modified files" {
            $result = Compare-BackupIntegrity -StateDirectory $script:stateDir
            
            $result.Modified | Should -HaveCount 1
            $result.Modified[0].Path | Should -Match "fileA.txt"
        }
        
        It "Should detect added files" {
            $result = Compare-BackupIntegrity -StateDirectory $script:stateDir
            
            $result.Added | Should -HaveCount 1
            $result.Added[0].RelativePath | Should -Match "fileC.txt"
        }
        
        It "Should detect deleted files" {
            $result = Compare-BackupIntegrity -StateDirectory $script:stateDir
            
            $result.Deleted | Should -HaveCount 1
            $result.Deleted[0].RelativePath | Should -Match "fileB.txt"
        }
        
        It "Should provide accurate summary" {
            $result = Compare-BackupIntegrity -StateDirectory $script:stateDir
            
            $result.Summary.AddedCount | Should -Be 1
            $result.Summary.ModifiedCount | Should -Be 1
            $result.Summary.DeletedCount | Should -Be 1
        }
    }
    
    Context "Hash comparison" {
        It "Should show different hashes for modified files" {
            $result = Compare-BackupIntegrity -StateDirectory $script:stateDir
            
            $modified = $result.Modified[0]
            $modified.PreviousHash | Should -Not -Be $modified.CurrentHash
        }
    }
}

Describe "Test-BackupIntegrity" {
    BeforeAll {
        # Create test source
        $script:sourceData = Join-Path $TestDrive "BackupSource"
        New-Item -Path $script:sourceData -ItemType Directory | Out-Null
        
        "Backup file 1" | Out-File (Join-Path $script:sourceData "backup1.txt")
        "Backup file 2" | Out-File (Join-Path $script:sourceData "backup2.txt")
        
        $subFolder = Join-Path $script:sourceData "subfolder"
        New-Item -Path $subFolder -ItemType Directory | Out-Null
        "Nested backup" | Out-File (Join-Path $subFolder "nested.txt")
        
        # Create backup
        $script:backupDir = Join-Path $TestDrive "TestBackup"
        Copy-Item -Path $script:sourceData -Destination $script:backupDir -Recurse
        
        # Save state
        $script:stateDir = Join-Path $TestDrive "BackupStates"
        Save-IntegrityState -SourcePath $script:sourceData -StateDirectory $script:stateDir
    }
    
    Context "Intact backup verification" {
        It "Should verify intact backup" {
            $result = Test-BackupIntegrity -BackupPath $script:backupDir -StateDirectory $script:stateDir
            
            $result.IsIntact | Should -Be $true
            $result.Summary.VerifiedCount | Should -Be 3
            $result.Summary.CorruptedCount | Should -Be 0
        }
        
        It "Should verify all files" {
            $result = Test-BackupIntegrity -BackupPath $script:backupDir -StateDirectory $script:stateDir
            
            $result.Verified | Should -HaveCount 3
            $result.Corrupted | Should -HaveCount 0
            $result.Missing | Should -HaveCount 0
        }
    }
    
    Context "Corrupted backup detection" {
        BeforeAll {
            # Corrupt a file
            "CORRUPTED!" | Out-File (Join-Path $script:backupDir "backup1.txt")
        }
        
        It "Should detect corrupted file" {
            $result = Test-BackupIntegrity -BackupPath $script:backupDir -StateDirectory $script:stateDir
            
            $result.IsIntact | Should -Be $false
            $result.Summary.CorruptedCount | Should -Be 1
        }
        
        It "Should show hash mismatch" {
            $result = Test-BackupIntegrity -BackupPath $script:backupDir -StateDirectory $script:stateDir
            
            $corrupted = $result.Corrupted[0]
            $corrupted.ExpectedHash | Should -Not -Be $corrupted.ActualHash
        }
    }
    
    Context "Missing file detection" {
        BeforeAll {
            # Remove a file
            Remove-Item (Join-Path $script:backupDir "backup2.txt")
        }
        
        It "Should detect missing file" {
            $result = Test-BackupIntegrity -BackupPath $script:backupDir -StateDirectory $script:stateDir
            
            $result.Summary.MissingCount | Should -Be 1
        }
    }
    
    Context "ZIP backup verification" {
        BeforeAll {
            # Create fresh backup
            $script:freshBackup = Join-Path $TestDrive "FreshBackup"
            Copy-Item -Path $script:sourceData -Destination $script:freshBackup -Recurse
            
            # Create ZIP
            $script:zipPath = Join-Path $TestDrive "backup.zip"
            Compress-Archive -Path "$script:freshBackup\*" -DestinationPath $script:zipPath
        }
        
        It "Should verify ZIP backup" {
            $result = Test-BackupIntegrity -BackupPath $script:zipPath -StateDirectory $script:stateDir
            
            $result.IsIntact | Should -Be $true
            $result.Summary.VerifiedCount | Should -Be 3
        }
        
        It "Should extract and verify ZIP contents" {
            $result = Test-BackupIntegrity -BackupPath $script:zipPath -StateDirectory $script:stateDir
            
            $result.Verified | Should -HaveCount 3
            $result.Corrupted | Should -HaveCount 0
        }
    }
    
    Context "Path handling" {
        It "Should accept relative path" {
            $currentDir = Get-Location
            try {
                Set-Location (Split-Path $script:backupDir -Parent)
                $relativePath = ".\$(Split-Path $script:backupDir -Leaf)"
                $result = Test-BackupIntegrity -BackupPath $relativePath -StateDirectory $script:stateDir
                $result | Should -Not -BeNullOrEmpty
            }
            finally {
                Set-Location $currentDir
            }
        }
        
        It "Should accept absolute path" {
            $result = Test-BackupIntegrity -BackupPath $script:backupDir -StateDirectory $script:stateDir
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
