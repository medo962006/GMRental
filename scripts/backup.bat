@echo off
REM Daily Supabase backup — runs backup_supabase.py from the project root
REM Called by Windows Task Scheduler at 3:00 AM daily

cd /d "%~dp0\.."
python scripts\backup_supabase.py >> scripts\backups\backup_log.txt 2>&1
