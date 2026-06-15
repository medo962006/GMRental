# setup_backup_task.ps1
# Run this ONCE in PowerShell (as your normal user, not admin) to install the daily backup.
# The task runs only when you're logged in + network is available.
# If your laptop is asleep or off, Windows skips it and won't run until next login.

$taskName = "SupabaseDailyBackup"
$projectDir = "C:\Users\ahmed\GMRental\hostel_management"
$pythonScript = Join-Path $projectDir "scripts\backup_supabase.py"
$pythonExe = "C:\Python314\python.exe"

# Python command: run the backup script from its directory
$arguments = "`"$pythonScript`""
$workingDir = $projectDir

$action = New-ScheduledTaskAction -Execute $pythonExe -Argument $arguments -WorkingDirectory $workingDir

# Daily at 3 AM — adjust time if you prefer
$trigger = New-ScheduledTaskTrigger -Daily -At "3:00 AM"

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
    -Description "Supabase daily backup — all 11 tables to local JSON" `
    -RunLevel Limited

Write-Host ""
Write-Host "[OK] Scheduled task '$taskName' created!" -ForegroundColor Green
Write-Host "  Schedule:  Daily at 3:00 AM"
Write-Host "  Runs when: Logged in + network available"
Write-Host "  Python:   $pythonExe"
Write-Host "  Script:   $pythonScript"
Write-Host "  Backups:  $projectDir\backups\"
Write-Host ""
Write-Host "Commands you might need:"
Write-Host "  Test now:   schtasks /run /tn $taskName"
Write-Host "  Check:     schtasks /query /tn $taskName"
Write-Host "  Disable:   schtasks /change /tn $taskName /disable"
Write-Host "  Remove:    schtasks /delete /tn $taskName /f"
