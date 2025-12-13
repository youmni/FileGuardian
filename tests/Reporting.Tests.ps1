BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:ReportingModulePath = Join-Path $ProjectRoot "src\Modules\Reporting"
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"
    
    # Import required modules
    Import-Module (Join-Path $script:LoggingModulePath "Write-Log.psm1") -Force
    Import-Module (Join-Path $script:ReportingModulePath "Write-JsonReport.psm1") -Force
    Import-Module (Join-Path $script:ReportingModulePath "Protect-Report.psm1") -Force
    Import-Module (Join-Path $script:ReportingModulePath "Confirm-ReportSignature.psm1") -Force
    
    # Helper function to create test backup info
    function script:New-TestBackupInfo {
        return @{
            BackupName = "TestBackup"
            Type = "Full"
            Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            Duration = New-TimeSpan -Seconds 45
            SourcePath = "C:\TestSource"
            DestinationPath = "C:\TestDestination"
            FilesBackedUp = 25
            TotalSizeMB = 150.5
            Compressed = $true
            CompressedSizeMB = 75.2
            CompressionRatio = 50.0
            IntegrityStateSaved = $true
        }
    }
}

Describe "Write-JsonReport" {
    BeforeEach {
        $script:TestReportDir = Join-Path $TestDrive "test_reports"
        New-Item -Path $script:TestReportDir -ItemType Directory -Force | Out-Null
        $script:TestReportPath = Join-Path $script:TestReportDir "test_report.json"
        $script:TestBackupInfo = New-TestBackupInfo
    }
    
    AfterEach {
        if (Test-Path $script:TestReportDir) {
            Remove-Item -Path $script:TestReportDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Report Generation" {
        It "Should create a JSON report file" {
            $result = Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath
            
            Test-Path $script:TestReportPath | Should -Be $true
            $result.ReportPath | Should -Be $script:TestReportPath
            $result.Format | Should -Be "JSON"
        }
        
        It "Should create valid JSON content" {
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath
            
            $content = Get-Content -Path $script:TestReportPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should include all required report sections" {
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath
            
            $report = Get-Content -Path $script:TestReportPath -Raw | ConvertFrom-Json
            
            $report.ReportMetadata | Should -Not -BeNullOrEmpty
            $report.BackupDetails | Should -Not -BeNullOrEmpty
            $report.Paths | Should -Not -BeNullOrEmpty
            $report.Statistics | Should -Not -BeNullOrEmpty
            $report.Integrity | Should -Not -BeNullOrEmpty
            $report.SystemInfo | Should -Not -BeNullOrEmpty
        }
        
        It "Should include correct backup details" {
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath
            
            $report = Get-Content -Path $script:TestReportPath -Raw | ConvertFrom-Json
            
            $report.BackupDetails.BackupName | Should -Be "TestBackup"
            $report.BackupDetails.Type | Should -Be "Full"
            $report.BackupDetails.Success | Should -Be $true
        }
        
        It "Should include correct statistics" {
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath
            
            $report = Get-Content -Path $script:TestReportPath -Raw | ConvertFrom-Json
            
            $report.Statistics.FilesBackedUp | Should -Be 25
            $report.Statistics.TotalSizeMB | Should -Be 150.5
            $report.Statistics.Compressed | Should -Be $true
            $report.Statistics.CompressedSizeMB | Should -Be 75.2
        }
        
        It "Should include system information" {
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath
            
            $report = Get-Content -Path $script:TestReportPath -Raw | ConvertFrom-Json
            
            $report.SystemInfo.ComputerName | Should -Be $env:COMPUTERNAME
            $report.SystemInfo.UserName | Should -Be $env:USERNAME
            $report.SystemInfo.OSVersion | Should -Not -BeNullOrEmpty
            $report.SystemInfo.PowerShellVersion | Should -Not -BeNullOrEmpty
        }
        
        It "Should create report directory if it doesn't exist" {
            $newReportPath = Join-Path $TestDrive "new_reports\subfolder\report.json"
            
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $newReportPath
            
            Test-Path $newReportPath | Should -Be $true
            Test-Path (Split-Path $newReportPath -Parent) | Should -Be $true
        }
        
        It "Should generate default path when ReportPath not specified" {
            $result = Write-JsonReport -BackupInfo $script:TestBackupInfo
            
            $result.ReportPath | Should -Not -BeNullOrEmpty
            Test-Path $result.ReportPath | Should -Be $true
            
            # Clean up generated file
            Remove-Item -Path $result.ReportPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Error Handling" {
        It "Should handle invalid path gracefully" {
            $invalidPath = "Z:\NonExistent\Path\report.json"
            
            { Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $invalidPath -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe "Protect-Report" {
    BeforeEach {
        $script:TestReportDir = Join-Path $TestDrive "test_reports"
        New-Item -Path $script:TestReportDir -ItemType Directory -Force | Out-Null
        $script:TestReportPath = Join-Path $script:TestReportDir "test_report.json"
        $script:TestBackupInfo = New-TestBackupInfo
        
        # Create a test report
        Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath | Out-Null
    }
    
    AfterEach {
        if (Test-Path $script:TestReportDir) {
            Remove-Item -Path $script:TestReportDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Report Signing" {
        It "Should create a signature file" {
            $result = Protect-Report -ReportPath $script:TestReportPath
            
            $signaturePath = "$($script:TestReportPath).sig"
            Test-Path $signaturePath | Should -Be $true
            $result.SignaturePath | Should -Be $signaturePath
        }
        
        It "Should create valid signature JSON content" {
            Protect-Report -ReportPath $script:TestReportPath
            
            $signaturePath = "$($script:TestReportPath).sig"
            $content = Get-Content -Path $signaturePath -Raw
            
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should include required signature fields" {
            Protect-Report -ReportPath $script:TestReportPath
            
            $signaturePath = "$($script:TestReportPath).sig"
            $signature = Get-Content -Path $signaturePath -Raw | ConvertFrom-Json
            
            $signature.ReportFile | Should -Not -BeNullOrEmpty
            $signature.Algorithm | Should -Not -BeNullOrEmpty
            $signature.Hash | Should -Not -BeNullOrEmpty
            $signature.SignedAt | Should -Not -BeNullOrEmpty
            $signature.SignedBy | Should -Not -BeNullOrEmpty
        }
        
        It "Should use SHA256 algorithm by default" {
            $result = Protect-Report -ReportPath $script:TestReportPath
            
            $result.Algorithm | Should -Be "SHA256"
        }
        
        It "Should support different algorithms" {
            $result = Protect-Report -ReportPath $script:TestReportPath -Algorithm "SHA1"
            
            $result.Algorithm | Should -Be "SHA1"
            $result.Hash.Length | Should -BeGreaterThan 0
        }
        
        It "Should calculate correct hash" {
            $result = Protect-Report -ReportPath $script:TestReportPath -Algorithm "SHA256"
            
            $expectedHash = (Get-FileHash -Path $script:TestReportPath -Algorithm SHA256).Hash
            $result.Hash | Should -Be $expectedHash
        }
        
        It "Should include correct signed by information" {
            Protect-Report -ReportPath $script:TestReportPath
            
            $signaturePath = "$($script:TestReportPath).sig"
            $signature = Get-Content -Path $signaturePath -Raw | ConvertFrom-Json
            
            $expectedSignedBy = "$env:USERNAME@$env:COMPUTERNAME"
            $signature.SignedBy | Should -Be $expectedSignedBy
        }
    }
    
    Context "Error Handling" {
        It "Should throw error for non-existent file" {
            $nonExistentPath = Join-Path $script:TestReportDir "nonexistent.json"
            
            { Protect-Report -ReportPath $nonExistentPath -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe "Confirm-ReportSignature" {
    BeforeEach {
        $script:TestReportDir = Join-Path $TestDrive "test_reports"
        New-Item -Path $script:TestReportDir -ItemType Directory -Force | Out-Null
        $script:TestReportPath = Join-Path $script:TestReportDir "test_report.json"
        $script:TestBackupInfo = New-TestBackupInfo
        
        # Create and sign a test report
        Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath | Out-Null
        Protect-Report -ReportPath $script:TestReportPath | Out-Null
    }
    
    AfterEach {
        if (Test-Path $script:TestReportDir) {
            Remove-Item -Path $script:TestReportDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Signature Verification" {
        It "Should verify valid signature" {
            $result = Confirm-ReportSignature -ReportPath $script:TestReportPath
            
            $result.IsValid | Should -Be $true
        }
        
        It "Should include verification details" {
            $result = Confirm-ReportSignature -ReportPath $script:TestReportPath
            
            $result.ReportPath | Should -Be $script:TestReportPath
            $result.ExpectedHash | Should -Not -BeNullOrEmpty
            $result.ActualHash | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Not -BeNullOrEmpty
            $result.SignedAt | Should -Not -BeNullOrEmpty
            $result.SignedBy | Should -Not -BeNullOrEmpty
        }
        
        It "Should match expected and actual hash for valid report" {
            $result = Confirm-ReportSignature -ReportPath $script:TestReportPath
            
            $result.ExpectedHash | Should -Be $result.ActualHash
        }
        
        It "Should detect tampered report" {
            # Tamper with the report
            Add-Content -Path $script:TestReportPath -Value "`n// Tampered" -NoNewline
            
            $result = Confirm-ReportSignature -ReportPath $script:TestReportPath
            
            $result.IsValid | Should -Be $false
            $result.ExpectedHash | Should -Not -Be $result.ActualHash
        }
        
        It "Should return false when signature file is missing" {
            # Remove signature file
            $signaturePath = "$($script:TestReportPath).sig"
            Remove-Item -Path $signaturePath -Force
            
            $result = Confirm-ReportSignature -ReportPath $script:TestReportPath
            
            $result | Should -Be $false
        }
    }
    
    Context "Error Handling" {
        It "Should throw error for non-existent report file" {
            $nonExistentPath = Join-Path $script:TestReportDir "nonexistent.json"
            
            { Confirm-ReportSignature -ReportPath $nonExistentPath -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe "Reporting Integration Tests" {
    BeforeEach {
        $script:TestReportDir = Join-Path $TestDrive "test_reports"
        New-Item -Path $script:TestReportDir -ItemType Directory -Force | Out-Null
        $script:TestReportPath = Join-Path $script:TestReportDir "integration_report.json"
        $script:TestBackupInfo = New-TestBackupInfo
    }
    
    AfterEach {
        if (Test-Path $script:TestReportDir) {
            Remove-Item -Path $script:TestReportDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Full Reporting Workflow" {
        It "Should complete full report generation and verification workflow" {
            # Generate report
            $reportResult = Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath
            $reportResult.ReportPath | Should -Be $script:TestReportPath
            
            # Sign report
            $signResult = Protect-Report -ReportPath $script:TestReportPath
            $signResult.SignaturePath | Should -Be "$($script:TestReportPath).sig"
            
            # Verify signature
            $verifyResult = Confirm-ReportSignature -ReportPath $script:TestReportPath
            $verifyResult.IsValid | Should -Be $true
        }
        
        It "Should detect tampering in full workflow" {
            # Generate and sign report
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $script:TestReportPath | Out-Null
            Protect-Report -ReportPath $script:TestReportPath | Out-Null
            
            # Tamper with report
            Add-Content -Path $script:TestReportPath -Value "`n// Modified"
            
            # Verify should fail
            $verifyResult = Confirm-ReportSignature -ReportPath $script:TestReportPath
            $verifyResult.IsValid | Should -Be $false
        }
        
        It "Should handle multiple reports in same directory" {
            $report1 = Join-Path $script:TestReportDir "report1.json"
            $report2 = Join-Path $script:TestReportDir "report2.json"
            
            # Create and sign multiple reports
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $report1 | Out-Null
            Write-JsonReport -BackupInfo $script:TestBackupInfo -ReportPath $report2 | Out-Null
            Protect-Report -ReportPath $report1 | Out-Null
            Protect-Report -ReportPath $report2 | Out-Null
            
            # Verify both
            (Confirm-ReportSignature -ReportPath $report1).IsValid | Should -Be $true
            (Confirm-ReportSignature -ReportPath $report2).IsValid | Should -Be $true
        }
    }
}
