@echo off
REM Supabase Daily Backup — Windows wrapper
REM Change to project root so Python script paths resolve correctly
cd /d "%~dp0\.."
echo Working dir: %CD%
set PYTHONIOENCODING=utf-8
python scripts\backup_supabase.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Backup FAILED! Check the output above.
    exit /b 1
)
echo.
echo Backup complete!
