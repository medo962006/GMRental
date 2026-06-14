@echo off
REM ════════════════════════════════════════════════════════
REM Hostel Manager — Windows Deployment Script
REM Run this from Windows Command Prompt (cmd.exe)
REM ════════════════════════════════════════════════════════

cd /d C:\Users\ahmed\GMRental\hostel_management

echo.
echo ════════════════════════════════════════════════════════
echo   Hostel Manager — Windows Deployment Pipeline
echo ════════════════════════════════════════════════════════
echo.
echo Select deployment target:
echo   1) Install Shorebird CLI (first-time)
echo   2) Shorebird Login
echo   3) Shorebird Init (first-time, after login)
echo   4) Shorebird Release Android (creates base OTA app)
echo   5) Shorebird Release iOS (creates base OTA app - requires Xcode)
echo   6) Shorebird Patch Android (push OTA update)
echo   7) Shorebird Patch iOS (push OTA update)
echo   8) Build APK only (no Shorebird)
echo   9) Full release: init + release android + patch android
echo   10) Exit
echo.
set /p choice=Enter choice [1-10]: 

if "%choice%"=="1" goto install
if "%choice%"=="2" goto login
if "%choice%"=="3" goto init
if "%choice%"=="4" goto release_android
if "%choice%"=="5" goto release_ios
if "%choice%"=="6" goto patch_android
if "%choice%"=="7" goto patch_ios
if "%choice%"=="8" goto build_apk
if "%choice%"=="9" goto full_release
if "%choice%"=="10" goto end
echo Invalid choice.
goto end

:install
echo.
echo Installing Shorebird CLI...
powershell -Command "Invoke-WebRequest -Uri https://raw.githubusercontent.com/shorebirdtech/install/main/install.ps1 -OutFile $env:TEMP\install-shorebird.ps1; & $env:TEMP\install-shorebird.ps1"
echo.
echo ✓ Shorebird CLI installed. Restart your terminal and run this script again.
goto end

:login
echo.
echo Opening Shorebird login...
shorebird login
goto end

:init
echo.
echo Initializing Shorebird in project...
shorebird init
echo.
echo ✓ Shorebird initialized. You can now create releases.
goto end

:release_android
echo.
echo Creating Shorebird Android release...
shorebird release android
echo.
echo ✓ Android release created!
echo   Users can now install the app via the Shorebird link.
goto end

:release_ios
echo.
echo Creating Shorebird iOS release...
shorebird release ios
echo.
echo ✓ iOS release created!
goto end

:patch_android
echo.
echo Pushing Shorebird patch to Android...
shorebird patch android
echo.
echo ✓ Android patch pushed! Devices will auto-update on next launch.
goto end

:patch_ios
echo.
echo Pushing Shorebird patch to iOS...
shorebird patch ios
echo.
echo ✓ iOS patch pushed! Devices will auto-update on next launch.
goto end

:build_apk
echo.
echo Building Android APK...
flutter build apk --release
echo.
echo ✓ APK built at: build\app\outputs\flutter-apk\app-release.apk
goto end

:full_release
echo.
echo ═══ Full Android Release ═══
echo.
echo Step 1: Initializing Shorebird...
shorebird init
echo.
echo Step 2: Creating Android release...
shorebird release android
echo.
echo Step 3: Pushing first patch...
shorebird patch android
echo.
echo ════════════════════════════════════════════════════════
echo   ✓ Full Android release complete!
echo   APK: build\app\outputs\flutter-apk\app-release.apk
echo   Shorebird: release + patch pushed
echo ════════════════════════════════════════════════════════
goto end

:end
