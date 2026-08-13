@echo off
REM Copies runtime assets next to the built executable.
REM Wire it up in RAD Studio: Project - Options - Building - Build Events -
REM Post-build, command line:  call "$(PROJECTDIR)\..\..\tools\copy-assets.bat"

setlocal
pushd "%~dp0.."
set "ROOT=%CD%"
popd

xcopy /Y /D /I "%ROOT%\assets\prompt_*.md"    "%ROOT%\bin\"        >nul
xcopy /Y /D /I "%ROOT%\assets\*.png"          "%ROOT%\bin\"        >nul
xcopy /Y /D /I "%ROOT%\assets\styles\*.style" "%ROOT%\bin\styles\" >nul
echo Assets copied to %ROOT%\bin
endlocal
