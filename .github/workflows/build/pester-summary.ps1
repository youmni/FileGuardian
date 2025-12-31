$ErrorActionPreference = 'Stop'

Import-Module Pester -MinimumVersion 5.0

Write-Host "Running Pester tests..."

$result = Invoke-Pester `
    -Path "tests" `
    -ExcludeTag "skip_ci" `
    -Output None `
    -PassThru

$tests = $result.Tests

if (-not $tests) {
    Write-Error "No tests found."
}

foreach ($test in $tests) {
    if ($test.Path -match 'tests[\\/]+([^\\/]+)') {
        $test | Add-Member -NotePropertyName Module -NotePropertyValue $matches[1]
    } else {
        $test | Add-Member -NotePropertyName Module -NotePropertyValue 'Unknown'
    }
}

$modules = $tests | Group-Object Module

$summaryLines = @()
$summaryLines += "# Test Summary"
$summaryLines += ""
$summaryLines += "## Overview by module"
$summaryLines += ""
$summaryLines += "| Module | Total | Passed | Failed | Success Rate |"
$summaryLines += "|--------|-------|--------|--------|--------------|"

foreach ($module in $modules) {
    $total  = $module.Count
    $passed = ($module.Group | Where-Object Result -eq 'Passed').Count
    $failed = ($module.Group | Where-Object Result -eq 'Failed').Count
    $percent = if ($total -gt 0) {
        [math]::Round(($passed / $total) * 100, 2)
    } else {
        0
    }

    $summaryLines += "| $($module.Name) | $total | $passed | $failed | $percent% |"
}

$summaryLines += ""
$summaryLines += "## Failed tests per module"
$summaryLines += ""

foreach ($module in $modules) {
    $failedTests = $module.Group | Where-Object Result -eq 'Failed'

    if ($failedTests.Count -eq 0) {
        continue
    }

    $summaryLines += "### $($module.Name)"
    $summaryLines += ""

    foreach ($test in $failedTests) {
        $summaryLines += "- **$($test.Name)**"
        if ($test.ErrorRecord) {
            $summaryLines += "  - $($test.ErrorRecord.Exception.Message)"
        }
    }

    $summaryLines += ""
}

$summaryPath = $env:GITHUB_STEP_SUMMARY
$summaryLines -join "`n" | Out-File -FilePath $summaryPath -Encoding utf8

if ($result.FailedCount -gt 0) {
    Write-Error "$($result.FailedCount) tests failed."
}