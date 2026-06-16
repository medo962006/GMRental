# backup_task.ps1 — place at C:\Users\ahmed\GMRental\hostel_management\scripts\setup_backup_task.ps1
# One-time setup: run this in PowerShell to install the daily Supabase backup task

$taskName = "SupabaseDailyBackup"
$projectDir = "C:\Users\ahmed\GMRental\hostel_management"
$pythonScript = Join-Path $projectDir "scripts\backup_supabase.py"
$pythonExe = "C:\Python314\python.exe"

$arguments = "`"$pythonScript`""
$workingDir = $projectDir

$action = New-ScheduledTaskAction -Execute $pythonExe -Argument $arguments -WorkingDirectory $workingDir

# Daily at 3:00 AM
$trigger = New-ScheduledTaskTrigger -Daily -At "03:00"

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Supabase daily backup - all tables to local JSON" `
    -RunLevel Limited

Write-Host ""
Write-Host "[OK] Scheduled task '$taskName' created!" -ForegroundColor Green
Write-Host "  Schedule:  Daily at 3:00 AM"
Write-Host "  Runs when: Logged in + network available"
Write-Host "  Python:   $pythonExe"
Write-Host "  Backups:  $projectDir\backups\"
Write-Host ""
Write-Host "Commands:"
Write-Host '  Test now:   schtasks /run /tn $taskName'
Write-Host '  Check:     schtasks /query /tn $taskName'
Write-Host '  Disable:   schtasks /change /tn $taskName /disable'
Write-Host '  Remove:    schtasks /delete /tn $taskName /f'
