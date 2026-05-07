@echo off
REM =============================================================================
REM Claimit Flutter recovery script  v2
REM
REM Use this when you see Gradle cache errors like:
REM   - "Could not read workspace metadata from .gradle/caches/8.x/transforms/..."
REM   - "Corrupted IndexBlock NNN found in cache .gradle/caches/journal-1/..."
REM   - "Configuration with name 'implementation' not found"
REM
REM Run from inside  E:\aroganamproject\claimit-app\claimit
REM =============================================================================

setlocal EnableDelayedExpansion
echo.
echo ==========================================================
echo   Claimit Flutter recovery script
echo ==========================================================
echo.

echo [1/9] Killing any stuck Java / Gradle / Kotlin daemons...
taskkill /F /IM java.exe       2>nul
taskkill /F /IM javaw.exe      2>nul
taskkill /F /IM kotlin-daemon.exe 2>nul
taskkill /F /IM gradle.exe     2>nul
taskkill /F /IM dart.exe       2>nul
taskkill /F /IM adb.exe        2>nul
timeout /t 2 >nul

echo.
echo [2/9] flutter clean...
call flutter clean

echo.
echo [3/9] Removing project build outputs...
if exist build              rmdir /S /Q build
if exist .dart_tool         rmdir /S /Q .dart_tool
if exist android\.gradle    rmdir /S /Q android\.gradle
if exist android\build      rmdir /S /Q android\build
if exist android\app\build  rmdir /S /Q android\app\build
if exist .flutter-plugins-dependencies del /Q .flutter-plugins-dependencies
if exist pubspec.lock       del /Q pubspec.lock

echo.
echo [4/9] Wiping the entire global Gradle cache (this is the safest fix
echo       for the IndexBlock / file-access.bin / transforms corruption).
echo       Gradle will re-download everything on the next build (~5-10 min).
echo.
choice /M "Delete %USERPROFILE%\.gradle\caches"
if errorlevel 2 goto :skip_global

if exist "%USERPROFILE%\.gradle\caches"      rmdir /S /Q "%USERPROFILE%\.gradle\caches"
if exist "%USERPROFILE%\.gradle\daemon"      rmdir /S /Q "%USERPROFILE%\.gradle\daemon"
if exist "%USERPROFILE%\.gradle\workers"     rmdir /S /Q "%USERPROFILE%\.gradle\workers"
echo Global Gradle cache deleted.
goto :after_global

:skip_global
echo Skipping global cache wipe; only deleting the corrupted sub-caches.
if exist "%USERPROFILE%\.gradle\caches\journal-1"   rmdir /S /Q "%USERPROFILE%\.gradle\caches\journal-1"
if exist "%USERPROFILE%\.gradle\caches\8.14"        rmdir /S /Q "%USERPROFILE%\.gradle\caches\8.14"
if exist "%USERPROFILE%\.gradle\caches\transforms-3" rmdir /S /Q "%USERPROFILE%\.gradle\caches\transforms-3"
if exist "%USERPROFILE%\.gradle\caches\transforms-4" rmdir /S /Q "%USERPROFILE%\.gradle\caches\transforms-4"

:after_global
echo.
echo [5/9] Wiping pub-cache copies of plugins that often go bad...
for /D %%D in ("%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\image_picker_android-*")  do rmdir /S /Q "%%D" 2>nul
for /D %%D in ("%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\image_picker-*")          do rmdir /S /Q "%%D" 2>nul
for /D %%D in ("%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\file_picker-*")           do rmdir /S /Q "%%D" 2>nul
for /D %%D in ("%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_secure_storage-*") do rmdir /S /Q "%%D" 2>nul
for /D %%D in ("%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\permission_handler*-*")    do rmdir /S /Q "%%D" 2>nul

echo.
echo [6/9] flutter pub get...
call flutter pub get
if errorlevel 1 goto :err

echo.
echo [7/9] Pre-warming the Gradle 8.10.2 wrapper...
pushd android
call gradlew.bat --version --no-daemon
call gradlew.bat --stop
popd

echo.
echo [8/9] flutter doctor -v...
call flutter doctor -v

echo.
echo [9/9] Done. Now run:
echo       flutter run -d emulator-5554       (or your device id)
echo.
echo If a build still fails, run this script again and answer Y to step 4.
echo.
goto :eof

:err
echo.
echo *** A step failed. Read the message above. ***
exit /b 1
