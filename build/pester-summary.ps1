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

$passed = ($tests | Where-Object Result -eq 'Passed').Count
$failed = ($tests | Where-Object Result -eq 'Failed').Count
$skipped = ($tests | Where-Object Result -eq 'Skipped').Count
$total = $tests.Count
$duration = $result.Duration
$successRate = if ($total -gt 0) {
    [math]::Round(($passed / $total) * 100, 2)
}
else {
    0
}

$testsByFile = $tests | Group-Object {
    [System.IO.Path]::GetFileName($_.ScriptBlock.File)
}

$summary = @()

$summary += "# Test Results"
$summary += ""
$summary += "## Status"
$summary += ""
$summary += "| Status | Count |"
$summary += "|--------|-------|"
$summary += "| Passed | $passed |"
$summary += "| Failed | $failed |"
$summary += "| Skipped | $skipped |"
$summary += "| Duration | $($duration.ToString()) |"
$summary += ""
$summary += "**Total Tests:** $total | **Success Rate:** $successRate%"
$summary += ""

$summary += "## Results by Test File"
$summary += ""
$summary += "| Report | Passed | Failed | Skipped | Time |"
$summary += "|--------|--------|--------|---------|------|"

foreach ($file in $testsByFile) {
    $filePassed = ($file.Group | Where-Object Result -eq 'Passed').Count
    $fileFailed = ($file.Group | Where-Object Result -eq 'Failed').Count
    $fileSkipped = ($file.Group | Where-Object Result -eq 'Skipped').Count
    $fileTotal = $file.Count
    $fileTime = ($file.Group | Measure-Object Duration -Sum).Sum

    $summary += "| $($file.Name) | $filePassed | $fileFailed | $fileSkipped | $([math]::Round($fileTime.TotalSeconds, 3))s |"
}

$summary += ""

$summary += "## Detailed Results"
$summary += ""

foreach ($file in $testsByFile) {
    $filePassed = ($file.Group | Where-Object Result -eq 'Passed').Count
    $fileFailed = ($file.Group | Where-Object Result -eq 'Failed').Count
    $fileSkipped = ($file.Group | Where-Object Result -eq 'Skipped').Count
    $fileTotal = $file.Count
    $fileTimeSeconds = (
        $file.Group |
        ForEach-Object { $_.Duration.TotalSeconds }
    ) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

    $fileTime = [TimeSpan]::FromSeconds($fileTimeSeconds)
    $fileRate = if ($fileTotal -gt 0) {
        [math]::Round(($filePassed / $fileTotal) * 100, 2)
    }
    else {
        0
    }

    $summary += "### $($file.Name) - $fileRate%"
    $summary += ""
    $summary += "$filePassed passed, $fileFailed failed, $fileSkipped skipped of $fileTotal total in $([math]::Round($fileTime.TotalSeconds, 3))s"
    $summary += ""

    if ($fileFailed -gt 0) {
        foreach ($test in ($file.Group | Where-Object Result -eq 'Failed')) {
            $summary += "- **$($test.Name)**"
            if ($test.ErrorRecord) {
                $summary += "  - $($test.ErrorRecord.Exception.Message)"
            }
        }
        $summary += ""
    }
}

$summary += "Job summary generated at run-time"

$summary -join "`n" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8

if ($failed -gt 0) {
    Write-Error "$failed tests failed."
}
