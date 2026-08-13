@echo off
REM ===========================================================================
REM  tree-to-clipboard.bat  (v3)
REM
REM  Dumps the folder structure and file list from its own location downward,
REM  prints it and copies it to the clipboard. Build output, IDE state and git
REM  internals are skipped - they are noise, and bin\ holds the API keys.
REM
REM  v1 filtered with findstr patterns ending in a backslash; the trailing
REM  backslash escaped the closing quote and the whole filter was ignored.
REM  v3 appends a trailing backslash before testing, so the last segment of
REM  a path (apps\DelphiLoop\__history) is caught like a nested one.
REM
REM  Usage:
REM    tree-to-clipboard.bat            scans the folder the script lives in
REM    tree-to-clipboard.bat <path>     scans that folder instead
REM ===========================================================================

setlocal EnableDelayedExpansion

if "%~1"=="" (set "TARGET=%~dp0") else (set "TARGET=%~1")

pushd "%TARGET%" 2>nul
if errorlevel 1 (
  echo   [STOP] Folder not found: %TARGET%
  goto :Done
)
set "ROOT=%CD%"
popd

set "OUT=%TEMP%\dlq_tree.txt"

REM Folders never reported, matched as whole path segments.
set "SKIPDIR=.git bin dcu __history __recovery Win32 Win64 Android Android64 OSX64 OSXARM64 iOSDevice64"

REM Extensions never reported.
set "SKIPEXT=.dcu .exe .map .rsm .drc .identcache .dsk .local .stat .otares .tvsconfig"

set /a FILES=0
set /a DIRS=0

> "%OUT%" (
  echo ROOT: %ROOT%
  echo DATE: %DATE% %TIME%
  echo.
  echo --- FOLDERS ---
)

for /f "delims=" %%D in ('dir /s /b /ad "%ROOT%" 2^>nul') do (
  set "P=%%D"
  set "P=!P:%ROOT%\=!"
  call :Keep "!P!"
  if "!OK!"=="1" (
    >> "%OUT%" echo   !P!\
    set /a DIRS+=1
  )
)

>> "%OUT%" (
  echo.
  echo --- FILES ---
)

for /f "delims=" %%F in ('dir /s /b /a-d "%ROOT%" 2^>nul') do (
  set "P=%%F"
  set "P=!P:%ROOT%\=!"
  call :Keep "!P!" "%%~xF"
  if "!OK!"=="1" (
    >> "%OUT%" echo   !P!  [%%~zF bytes]
    set /a FILES+=1
  )
)

>> "%OUT%" (
  echo.
  echo --- %DIRS% folders, %FILES% files ^(build output and git internals skipped^) ---
)

type "%OUT%"
clip < "%OUT%"
del "%OUT%" >nul 2>&1

echo.
echo   Copied to clipboard: %DIRS% folders, %FILES% files.
echo.

goto :Done

REM ---------------------------------------------------------------------------
REM  Keep  %1 = relative path, %2 = extension (files only). Sets OK to 0 or 1.
REM  Rejects the path if it is a skipped folder or lies inside one, or if the
REM  extension is on the skip list.
REM ---------------------------------------------------------------------------
:Keep
set "OK=1"
set "REL=%~1"
set "EXT=%~2"
set "TEST=%~1\"

for %%S in (%SKIPDIR%) do (
  if /i "!TEST:%%S\=!" neq "!TEST!" set "OK=0"
)

if not "%EXT%"=="" (
  for %%E in (%SKIPEXT%) do (
    if /i "%EXT%"=="%%E" set "OK=0"
  )
)
goto :eof

:Done
endlocal
pause
