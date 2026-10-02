@echo off
rem Hotline Miami co-op installer. Usage: install.bat [path\to\hotline_miami]
rem Uses the Python bundled in the "python" folder (nothing to install).
setlocal
set "PY="
if exist "%~dp0python\python.exe" set PY="%~dp0python\python.exe"
if not defined PY where py >nul 2>nul && set "PY=py -3"
if not defined PY set "PY=python"
set PYTHONIOENCODING=utf-8
%PY% "%~dp0tools\install.py" %*
pause
