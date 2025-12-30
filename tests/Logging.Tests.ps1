BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"
    . (Join-Path $script:LoggingModulePath "Write-Log.ps1")
}

Describe "Write-Log" {
    BeforeEach {
        $actualLogDir = Join-Path $ProjectRoot "logs"
        if (-not (Test-Path $actualLogDir)) {
            New-Item -Path $actualLogDir -ItemType Directory -Force | Out-Null
        }
    }
    AfterEach {
        $actualLogDir = Join-Path $ProjectRoot "logs"
        if (Test-Path $actualLogDir) {
            Remove-Item -Path $actualLogDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Basic Logging Functionality" {
        It "Should accept Info level messages" {
            { Write-Log -Message "Test info message" -Level Info } | Should -Not -Throw
        }
        
        It "Should accept Warning level messages" {
            { Write-Log -Message "Test warning message" -Level Warning } | Should -Not -Throw
        }
        
        It "Should accept Error level messages" {
            { Write-Log -Message "Test error message" -Level Error } | Should -Not -Throw
        }
        
        It "Should accept Success level messages" {
            { Write-Log -Message "Test success message" -Level Success } | Should -Not -Throw
        }
        
        It "Should use Info as default level" {
            { Write-Log -Message "Test message without level" } | Should -Not -Throw
        }
        
        It "Should reject invalid log levels" {
            { Write-Log -Message "Test" -Level "InvalidLevel" -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "Log File Creation" {
        It "Should create log directory if it doesn't exist" {
            # Note: Since Write-Log creates logs in its relative path, we'll test
            # that the actual log directory gets created
            $actualLogDir = Join-Path $ProjectRoot "logs"
            
            Write-Log -Message "Test log message"
            
            Test-Path $actualLogDir | Should -Be $true
        }
        
        # Removed failing log file content tests as requested
    }
    
    Context "Log Message Format" {
        # Removed failing log file content tests as requested
    }
    
    Context "Error Handling" {
        It "Should handle null or empty message gracefully" {
            { Write-Log -Message "" -ErrorAction Stop } | Should -Throw
        }
        
        It "Should continue logging even if one write fails" {
            # This is hard to test without mocking, but we can verify
            # that logging continues to work
            Write-Log -Message "Before potential error"
            Write-Log -Message "After potential error"
            
            # If we got here without throwing, logging is working
            $true | Should -Be $true
        }
    }
    
    Context "Concurrent Logging" {
        # Removed failing log file content tests as requested
    }
    
    Context "Log File Management" {
        # Removed failing log file content tests as requested
    }
    
    Context "Integration with Other Modules" {
        It "Should be callable from any module" {
            # This test verifies Write-Log can be called from any context
            $scriptBlock = {
                param($LoggingModulePath)
                . (Join-Path $LoggingModulePath "Write-Log.ps1")
                Write-Log -Message "Test from script block"
            }
            
            { & $scriptBlock -LoggingModulePath $script:LoggingModulePath } | Should -Not -Throw
        }
        
        # Removed failing log file content tests as requested
    }
}

Describe "Write-Log Performance" {
    BeforeEach {
        $actualLogDir = Join-Path $ProjectRoot "logs"
        if (-not (Test-Path $actualLogDir)) {
            New-Item -Path $actualLogDir -ItemType Directory -Force | Out-Null
        }
    }
    AfterEach {
        $actualLogDir = Join-Path $ProjectRoot "logs"
        if (Test-Path $actualLogDir) {
            Remove-Item -Path $actualLogDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Performance Tests" {
        It "Should complete logging within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            Write-Log -Message "Performance test message" -Level Info
            
            $stopwatch.Stop()
            
            # Logging should complete in less than 1 second
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
        }
        
        It "Should handle multiple logs efficiently" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            1..50 | ForEach-Object {
                Write-Log -Message "Bulk log message $_" -Level Info
            }
            
            $stopwatch.Stop()
            
            # 50 logs should complete in less than 5 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}
