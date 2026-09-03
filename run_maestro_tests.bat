@echo off
setlocal enabledelayedexpansion

echo ===============================================================================
echo               MAESTRO AUTOMATED MOBILE E2E TEST RUNNER
echo ===============================================================================
echo Configuring Android SDK and Maestro environment...

:: Set Java Home
set "JAVA_HOME=C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot"
set "PATH=%JAVA_HOME%\bin;%LOCALAPPDATA%\Android\Sdk\platform-tools;C:\Users\Lenovo\maestro\maestro\bin;%PATH%"
set "MAESTRO_CLI_NO_ANALYTICS=1"
set "MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true"

:: Check ADB and connected devices
echo Checking connected Android devices...
adb devices
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] ADB failed to run. Please check Android platform-tools.
    exit /b 1
)

echo.
echo ===============================================================================
echo [1/2] RUNNING SVIP PRIVILEGES AUTOMATED FLOW (.maestro/svip_flow.yaml)
echo ===============================================================================
call maestro test .maestro\svip_flow.yaml
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] SVIP flow encountered a step failure or app was not in foreground.
) else (
    echo [PASS] SVIP automated flow completed successfully!
)

echo.
echo ===============================================================================
echo [2/2] RUNNING OFFLINE BETTING AUTOMATED FLOW (.maestro/offline_betting_flow.yaml)
echo ===============================================================================
call maestro test .maestro\offline_betting_flow.yaml
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] Offline betting flow encountered a step failure.
) else (
    echo [PASS] Offline betting automated flow completed successfully!
)

echo.
echo ===============================================================================
echo                   MAESTRO TEST RUN FINISHED
echo ===============================================================================