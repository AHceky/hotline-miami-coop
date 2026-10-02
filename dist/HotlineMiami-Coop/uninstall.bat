@echo off
rem Removes HotlineMiami_Coop.exe and hmnet.dll from the game folder. Usage: uninstall.bat [path\to\hotline_miami]
setlocal
set "PY="
if exist "%~dp0python\python.exe" set PY="%~dp0python\python.exe"
if not defined PY where py >nul 2>nul && set "PY=py -3"
if not defined PY set "PY=python"
set PYTHONIOENCODING=utf-8
%PY% "%~dp0tools\install.py" %* --uninstall
pause
