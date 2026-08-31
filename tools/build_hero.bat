@echo off
REM Rebuild the player character from assets/source/hero_sheet.png
REM
REM   tools\build_hero.bat --dry-run
REM   tools\build_hero.bat
REM
REM Uses the test3 virtualenv; Blender is required for the animation step.
REM NOTE: keep this file ASCII-only. cmd.exe reads .bat in the OEM codepage.
chcp 65001 >nul 2>&1
set PYTHONIOENCODING=utf-8
"C:\_project\test3\.venv\Scripts\python.exe" -u "%~dp0build_hero.py" %*
echo.
echo [exit code %errorlevel%]
