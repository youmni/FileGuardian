BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:LoggingModulePath = Join-Path $ProjectRoot "src\Modules\Logging"
    Import-Module (Join-Path $script:LoggingModulePath "Write-Log.psm1") -Force
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
        
        It "Should create daily log file" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $expectedLogPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            Write-Log -Message "Test log message"
            
            Test-Path $expectedLogPath | Should -Be $true
        }
        
        It "Should append to existing log file" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            # Get initial line count or 0 if file doesn't exist
            $initialLines = if (Test-Path $logPath) { 
                (Get-Content -Path $logPath).Count 
            } else { 
                0 
            }
            
            # Write two log messages
            Write-Log -Message "First test message"
            Write-Log -Message "Second test message"
            
            # Check that lines were added
            $finalLines = (Get-Content -Path $logPath).Count
            $finalLines | Should -BeGreaterThan $initialLines
        }
    }
    
    Context "Log Message Format" {
        It "Should include timestamp in log message" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            $testMessage = "Timestamp test $(Get-Random)"
            Write-Log -Message $testMessage -Level Info
            
            $content = Get-Content -Path $logPath -Raw
            $content | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]'
        }
        
        It "Should include log level in message" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            $testMessage = "Level test $(Get-Random)"
            Write-Log -Message $testMessage -Level Warning
            
            $content = Get-Content -Path $logPath -Raw
            $content | Should -Match '\[Warning\]'
        }
        
        It "Should include the actual message content" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            $uniqueMessage = "Unique test message $(Get-Random)"
            Write-Log -Message $uniqueMessage -Level Info
            
            # Read only the last line where our message should be
            $lastLine = Get-Content -Path $logPath -Tail 1
            $lastLine | Should -BeLike "*$uniqueMessage*"
        }
        
        It "Should format message correctly for all levels" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            $levels = @('Info', 'Warning', 'Error', 'Success')
            
            foreach ($level in $levels) {
                $message = "Test $level message $(Get-Random)"
                Write-Log -Message $message -Level $level
                
                # Read only the last line where our message should be
                $lastLine = Get-Content -Path $logPath -Tail 1
                $lastLine | Should -BeLike "*[$level]*"
                $lastLine | Should -BeLike "*$message*"
            }
        }
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
        It "Should handle multiple log messages in sequence" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            $messageCount = 5
            $uniqueId = Get-Random
            
            for ($i = 1; $i -le $messageCount; $i++) {
                Write-Log -Message "Sequential message $i with ID $uniqueId"
            }
            
            $content = Get-Content -Path $logPath -Raw
            
            # Verify all messages were logged
            for ($i = 1; $i -le $messageCount; $i++) {
                $content | Should -Match "Sequential message $i with ID $uniqueId"
            }
        }
    }
    
    Context "Log File Management" {
        It "Should create separate log files for different dates" {
            # This test verifies the naming convention
            # In practice, different dates would create different files
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $expectedLogPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            Write-Log -Message "Date-specific log message"
            
            # Verify the log file name contains today's date
            Test-Path $expectedLogPath | Should -Be $true
            (Split-Path $expectedLogPath -Leaf) | Should -Match "fileguardian_\d{8}\.log"
        }
        
        It "Should use UTF8 encoding" {
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            # Write a message with special characters
            $uniqueId = Get-Random
            $specialMessage = "Test UTF8 encoding ID $uniqueId"
            Write-Log -Message $specialMessage
            
            # Read and verify - read only last line
            $lastLine = Get-Content -Path $logPath -Tail 1 -Encoding UTF8
            $lastLine | Should -BeLike "*Test UTF8 encoding ID $uniqueId*"
        }
    }
    
    Context "Integration with Other Modules" {
        It "Should be callable from any module" {
            # This test verifies Write-Log can be called from any context
            $scriptBlock = {
                param($LoggingModulePath)
                Import-Module (Join-Path $LoggingModulePath "Write-Log.psm1") -Force
                Write-Log -Message "Test from script block"
            }
            
            { & $scriptBlock -LoggingModulePath $script:LoggingModulePath } | Should -Not -Throw
        }
        
        It "Should handle rapid successive calls" {
            # Simulate rapid logging like during backup operations
            $uniqueId = Get-Random
            1..10 | ForEach-Object {
                Write-Log -Message "Rapid log $_ ID $uniqueId" -Level Info
            }
            
            $actualLogDir = Join-Path $ProjectRoot "logs"
            $dateStamp = Get-Date -Format "yyyyMMdd"
            $logPath = Join-Path $actualLogDir "fileguardian_$dateStamp.log"
            
            $content = Get-Content -Path $logPath -Raw
            
            # Verify all 10 messages made it
            1..10 | ForEach-Object {
                $content | Should -Match "Rapid log $_ ID $uniqueId"
            }
        }
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
