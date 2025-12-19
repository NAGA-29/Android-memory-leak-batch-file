@echo off
setlocal enabledelayedexpansion

chcp 65001 > nul

set "PACKAGE=your.package.name"
set "DEVICE="
set "BASE_LOG_DIR=C:\Users\YourName\Debug\Directory\memory_leak\usb"

set "INTERVAL_INITIAL=60"
set "INITIAL_LOOPS=20"
set "INTERVAL=300"

set "LOGCAT_FILTER=-v threadtime -b main,events,system -s art:D dalvikvm:D GC:D *:I"

for /f "usebackq delims=" %%A in (`powershell -Command "Get-Date -Format 'yyyyMMdd'"`) do set "DATE=%%A"
for /f "usebackq delims=" %%A in (`powershell -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"`) do set "TIMESTAMP=%%A"

set "LOG_DIR=%BASE_LOG_DIR%\%DATE%"
set "METRICS_FILE=%LOG_DIR%\metrics_%TIMESTAMP%.csv"
set "RUN_INFO_FILE=%LOG_DIR%\run_info_%TIMESTAMP%.txt"
set "LOGCAT_FILE=%LOG_DIR%\logcat_%TIMESTAMP%.txt"

if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" || (echo ERROR: cannot create log dir & exit /b 1)
)

adb version > nul
if errorlevel 1 (
    echo ERROR: adb not found
    pause
    exit /b 1
)

if not defined DEVICE (
    for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (
        if "%%B"=="device" if not defined DEVICE set "DEVICE=%%A"
    )
)

if not defined DEVICE (
    echo ERROR: no USB device detected
    pause
    exit /b 1
)

set "DEVICE_OPT=-s %DEVICE%"
echo device: %DEVICE%

adb %DEVICE_OPT% shell pm list packages | findstr /i "%PACKAGE%" > nul
if errorlevel 1 (
    echo ERROR: package not found %PACKAGE%
    pause
    exit /b 1
)

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

echo start logcat: %LOGCAT_FILE%
start "logcat" /b adb %DEVICE_OPT% logcat %LOGCAT_FILTER% > "%LOGCAT_FILE%"

echo iso_time,pid,uptime_s,pss_kb,native_heap_kb,dalvik_heap_kb,graphics_kb,cpu_pct,proc_name,memfree_kb,memavail_kb,cached_kb,swapfree_kb,swap_kb,swappss_kb,pgfault,pgmajfault,pid_changed>"%METRICS_FILE%"

echo ==========================================
echo LOGGING START for: %PACKAGE%
echo LOG DIR: %LOG_DIR%
echo DEVICE: %DEVICE%
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
    set "SWAP_PROC=NA"
    set "SWAPPSS_PROC=NA"
    set "MEMFREE=NA"
    set "MEMAVAIL=NA"
    set "CACHED=NA"
    set "SWAPFREE=NA"
    set "PGFAULT=NA"
    set "PGMAJFAULT=NA"
    set "PID_CHANGE=0"

    for /f "usebackq delims=" %%A in (`powershell -Command "Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'"`) do set "CUR_ISO=%%A"
    for /f "usebackq tokens=1" %%A in (`adb %DEVICE_OPT% shell cat /proc/uptime 2^>NUL`) do set "UPTIME=%%A"

    for /f "usebackq" %%A in (`adb %DEVICE_OPT% shell pidof -s %PACKAGE% 2^>NUL`) do set "PID=%%A"

    if defined PID (
        if defined LAST_PID if not "!LAST_PID!"=="!PID!" set "PID_CHANGE=1"
        set "LAST_PID=!PID!"

        set "PSS="&set "NATIVE="&set "DALVIK="&set "GRAPHICS="
        for /f "usebackq tokens=2 delims=," %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo -c %PACKAGE% 2^>NUL ^| findstr /C:",TOTAL,"`) do set "PSS=%%A"
        for /f "usebackq tokens=2 delims=," %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo -c %PACKAGE% 2^>NUL ^| findstr /C:",Native Heap,"`) do set "NATIVE=%%A"
        for /f "usebackq tokens=2 delims=," %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo -c %PACKAGE% 2^>NUL ^| findstr /C:",Dalvik Heap,"`) do set "DALVIK=%%A"
        for /f "usebackq tokens=2 delims=," %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo -c %PACKAGE% 2^>NUL ^| findstr /C:",Graphics,"`) do set "GRAPHICS=%%A"

        if not defined PSS (
            for /f "usebackq tokens=2,3" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /C:"TOTAL"`) do (
                if "%%A"=="PSS:" (set "PSS=%%B") else set "PSS=%%A"
            )
        )
        if not defined NATIVE (
            for /f "usebackq tokens=1-5" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /C:"Native Heap"`) do (
                if "%%B"=="Heap:" (set "NATIVE=%%C") else if "%%B"=="Heap" (set "NATIVE=%%C") else set "NATIVE=%%B"
            )
        )
        if not defined DALVIK (
            for /f "usebackq tokens=1-5" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /C:"Dalvik Heap"`) do (
                if "%%B"=="Heap:" (set "DALVIK=%%C") else if "%%B"=="Heap" (set "DALVIK=%%C") else set "DALVIK=%%B"
            )
        )
        if not defined GRAPHICS (
            for /f "usebackq tokens=2,3" %%A in (`adb %DEVICE_OPT% shell dumpsys meminfo %PACKAGE% 2^>NUL ^| findstr /C:"Graphics"`) do (
                if "%%A"=="Graphics" (set "GRAPHICS=%%B") else set "GRAPHICS=%%A"
            )
        )

        for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/!PID!/smaps_rollup 2^>NUL ^| findstr /B /C:"Swap:"`) do set "SWAP_PROC=%%A"
        for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/!PID!/smaps_rollup 2^>NUL ^| findstr /B /C:"SwapPss:"`) do set "SWAPPSS_PROC=%%A"
        if "!SWAP_PROC!"=="NA" (
            for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/!PID!/status 2^>NUL ^| findstr /B /C:"VmSwap"`) do set "SWAP_PROC=%%A"
        )

        for /f "usebackq tokens=1" %%A in (`adb %DEVICE_OPT% shell dumpsys cpuinfo %PACKAGE% 2^>NUL ^| findstr "%PACKAGE%"`) do (
            set "CPU=%%A"
            set "CPU=!CPU:%%=!"
        )
    )

    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"MemFree"`) do set "MEMFREE=%%A"
    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"MemAvailable"`) do set "MEMAVAIL=%%A"
    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"Cached"`) do set "CACHED=%%A"
    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/meminfo 2^>NUL ^| findstr /B /C:"SwapFree"`) do set "SWAPFREE=%%A"

    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/vmstat 2^>NUL ^| findstr /B /C:"pgfault"`) do set "PGFAULT=%%A"
    for /f "usebackq tokens=2" %%A in (`adb %DEVICE_OPT% shell cat /proc/vmstat 2^>NUL ^| findstr /B /C:"pgmajfault"`) do set "PGMAJFAULT=%%A"

    echo !CUR_ISO!,!PID!,!UPTIME!,!PSS!,!NATIVE!,!DALVIK!,!GRAPHICS!,!CPU!,%PACKAGE%,!MEMFREE!,!MEMAVAIL!,!CACHED!,!SWAPFREE!,!SWAP_PROC!,!SWAPPSS_PROC!,!PGFAULT!,!PGMAJFAULT!,!PID_CHANGE!>>"%METRICS_FILE%"
    echo [!CUR_ISO!] logged (PID=!PID! PSS=!PSS! CPU=!CPU! delay=!LOOP_DELAY!s)

    set /a LOOP+=1
    timeout /t !LOOP_DELAY! > nul
    goto loop

endlocal
