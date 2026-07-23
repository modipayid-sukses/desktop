@echo off
title Launcher Aplikasi Modipay - Flutter
cls
echo =========================================================
echo       LAUNCHER OTOMATIS APLIKASI MODIPAY (FLUTTER)
echo =========================================================
echo.

:: Konfigurasi Path Sistem Anda
set "FLUTTER_BAT=D:\Project\src\flutter\bin\flutter.bat"
set "EMULATOR_EXE=C:\Users\yufit\AppData\Local\Android\Sdk\emulator\emulator.exe"
set "ADB_EXE=C:\Users\yufit\AppData\Local\Android\Sdk\platform-tools\adb.exe"

:: 1. Memeriksa status emulator
echo [1/3] Memeriksa status emulator Android...
"%ADB_EXE%" devices | findstr "emulator-5554" >nul
if %errorlevel% equ 0 goto emulator_active

echo [*] Emulator tidak terdeteksi aktif.
echo [*] Menyalakan emulator Pixel 6 Pro (Cold Boot)...
start /min "" "%EMULATOR_EXE%" -avd Pixel_6_Pro -no-snapshot-load
echo [*] Menunggu sistem Android pada emulator melakukan booting...

:wait_loop
timeout /t 5 >nul
"%ADB_EXE%" devices | findstr "emulator-5554" >nul
if %errorlevel% neq 0 goto wait_loop

echo [OK] Emulator berhasil terhubung!
goto emulator_done

:emulator_active
echo [OK] Emulator sudah aktif dan terhubung.

:emulator_done
echo [*] Melakukan port forwarding adb reverse tcp:8080 tcp:8080...
"%ADB_EXE%" reverse tcp:8080 tcp:8080
if %errorlevel% neq 0 (
    echo [WARNING] Gagal melakukan port forwarding adb reverse.
) else (
    echo [OK] Port forwarding berhasil!
)
echo.

:: 2. Menyelaraskan dependencies
echo [2/3] Memeriksa dependencies proyek (flutter pub get)...
call "%FLUTTER_BAT%" pub get
if %errorlevel% neq 0 (
    echo [EROR] Gagal meresolusi dependencies. Silakan periksa koneksi internet Anda.
    pause
    exit /b %errorlevel%
)
echo [OK] Dependencies siap.
echo.

:: 3. Menjalankan aplikasi
echo [3/3] Memulai kompilasi dan menjalankan aplikasi...
echo [*] Memastikan port forwarding adb reverse tcp:8080 tcp:8080...
"%ADB_EXE%" reverse tcp:8080 tcp:8080
echo [*] Tekan tombol 'r' di jendela ini untuk Hot Reload (Live Update).
echo [*] Tekan tombol 'R' untuk Hot Restart.
echo [*] Tekan tombol 'q' untuk berhenti.
echo ---------------------------------------------------------
call "%FLUTTER_BAT%" run -d emulator-5554 --dart-define=API_BASE_URL=https://dev.modipay.biz.id/api

pause
