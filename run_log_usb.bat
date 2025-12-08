@echo off
setlocal enabledelayedexpansion

chcp 65001 > nul

:: ================= 設定 =================
set "PACKAGE=your.package.name"
:: USBで自動検出する場合は空のまま。特定デバイスを明示したい場合のみ設定。
set "DEVICE="
set "LOG_DIR=C:\Users\YourName\Debug\Directory\memory_leak\usb"

:: 取得間隔（秒）: 初期は細かく、その後は通常間隔
set "INTERVAL_INITIAL=60"
set "INITIAL_LOOPS=20"
set "INTERVAL=300"

:: ログレベル（logcatフィルタ）
set "LOGCAT_FILTER=-v threadtime -b main,events,system -s art:D dalvikvm:D GC:D *:I"
:: ==========================================

:: 日時取得 (YYYYMMDD_HHMMSS形式)
for /f "usebackq delims=" %%A in (`powershell -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"`) do set "TIMESTAMP=%%A"

set "METRICS_FILE=%LOG_DIR%\metrics_%TIMESTAMP%.csv"
set "RUN_INFO_FILE=%LOG_DIR%\run_info_%TIMESTAMP%.txt"
set "LOGCAT_FILE=%LOG_DIR%\logcat_%TIMESTAMP%.txt"

:: ------------------ 準備 ------------------
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" || (echo ERROR: ログ出力先を作成できません & exit /b 1)
)

adb version > nul
if errorlevel 1 (
    echo ERROR: adbコマンドが見つかりません
    pause
    exit /b 1
)

:: USB接続デバイスの自動検出（DEVICE未指定の場合）
if not defined DEVICE (
    for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (
        if "%%B"=="device" if not defined DEVICE set "DEVICE=%%A"
    )
)

if not defined DEVICE (
    echo ERROR: USB接続のデバイスが見つかりません。接続を確認してください。
    pause
    exit /b 1
)

set "DEVICE_OPT=-s %DEVICE%"

echo 使用デバイス: %DEVICE%

:: パッケージ存在確認
adb %DEVICE_OPT% shell pm list packages | findstr /i "%PACKAGE%" > nul
if errorlevel 1 (
    echo ERROR: 指定パッケージが見つかりません %PACKAGE%
    pause
    exit /b 1
)

:: メタ情報取得
echo ==== RUN INFO (%TIMESTAMP%) ==== > "%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell getprop ro.product.model 2^>NUL`) do echo model=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell getprop ro.build.display.id 2^>NUL`) do echo build=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell getprop ro.product.cpu.abi 2^>NUL`) do echo abi=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"MemTotal"`) do echo mem_total_kb=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell getprop ro.build.version.release 2^>NUL`) do echo android_ver=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell dumpsys package %PACKAGE% 2^>NUL ^| findstr /R "versionName"`) do echo app_version=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell settings get global bluetooth_on 2^>NUL`) do echo bt=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell settings get global wifi_on 2^>NUL`) do echo wifi=%%A>>"%RUN_INFO_FILE%"
for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell dumpsys battery 2^>NUL ^| findstr /C:"level"`) do echo battery=%%A>>"%RUN_INFO_FILE%"

:: logcat開始（別プロセス）
echo logcat開始: %LOGCAT_FILE%
start "logcat" /b adb %DEVICE_OPT% logcat %LOGCAT_FILTER% > "%LOGCAT_FILE%"

:: CSVヘッダ
echo iso_time,pid,uptime_s,pss_kb,native_heap_kb,dalvik_heap_kb,graphics_kb,cpu_pct,proc_name,memfree_kb,cached_kb,swapfree_kb,pgfault,pgmajfault,pid_changed>"%METRICS_FILE%"

echo ==========================================
echo  LOGGING START for: %PACKAGE%
echo  出力先: %LOG_DIR%
echo  デバイス: %DEVICE%
echo ==========================================

set "LOOP=0"
set "LAST_PID="

:loop
    set "LOOP_DELAY=%INTERVAL%"
    if !LOOP! lss %INITIAL_LOOPS% set "LOOP_DELAY=%INTERVAL_INITIAL%"

    set "CUR_ISO=NA"
    set "UPTIME=NA"
    set "PID=NA"
    set "PSS=NA"
    set "NATIVE=NA"
    set "DALVIK=NA"
    set "GRAPHICS=NA"
    set "CPU=NA"
    set "MEMFREE=NA"
    set "CACHED=NA"
    set "SWAPFREE=NA"
    set "PGFAULT=NA"
    set "PGMAJFAULT=NA"
    set "PID_CHANGE=0"

    for /f "usebackq delims=" %%A in (`adb %DEVICE_OPT% shell date -Ins 2^>NUL`) do set "CUR_ISO=%%A"
    for /f "usebackq tokens=1" %%A in (`adb %DEVICE_OPT% shell cat /proc/uptime 2^>NUL`) do set "UPTIME=%%A"

    for /f "usebackq" %%A in (`adb %DEVICE_OPT% shell pidof -s %PACKAGE% 2^>NUL`) do set "PID=%%A"

    if defined PID (
        if defined LAST_PID if not "!LAST_PID!"=="!PID!" set "PID_CHANGE=1"
        set "LAST_PID=!PID!"

        for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /B /C:"TOTAL"`) do set "PSS=%%A"
        for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /C:"Native Heap"`) do set "NATIVE=%%A"
        for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /C:"Dalvik Heap"`) do set "DALVIK=%%A"
        for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /C:"Graphics"`) do set "GRAPHICS=%%A"

        for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell top -b -n 1 -o PID,CPU,RES,PR,PCY,NAME 2^>NUL ^| findstr " !PID! "`) do (
            set "CPU=%%A"
            set "CPU=!CPU:%%=!"
        )
    )

    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"MemFree"`) do set "MEMFREE=%%A"
    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"Cached"`) do set "CACHED=%%A"
    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"SwapFree"`) do set "SWAPFREE=%%A"

    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/vmstat 2^>NUL ^| findstr /B /C:"pgfault"`) do set "PGFAULT=%%A"
    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/vmstat 2^>NUL ^| findstr /B /C:"pgmajfault"`) do set "PGMAJFAULT=%%A"

    echo !CUR_ISO!,!PID!,!UPTIME!,!PSS!,!NATIVE!,!DALVIK!,!GRAPHICS!,!CPU!,%PACKAGE%,!MEMFREE!,!CACHED!,!SWAPFREE!,!PGFAULT!,!PGMAJFAULT!,!PID_CHANGE!>>"%METRICS_FILE%"
    echo [!CUR_ISO!] logged (PID=!PID! PSS=!PSS! CPU=!CPU! delay=!LOOP_DELAY!s)

    set /a LOOP+=1
    timeout /t !LOOP_DELAY! > nul
    goto loop

endlocal
