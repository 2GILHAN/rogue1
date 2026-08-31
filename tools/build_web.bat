@echo off
REM Build the web export into build\web
REM   tools\build_web.bat
REM NOTE: keep this file ASCII-only. cmd.exe reads .bat in the OEM codepage.
setlocal
if "%GODOT%"=="" set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
if not exist "%GODOT%" (
  echo Godot not found: %GODOT%
  exit /b 1
)
"%GODOT%" --headless --path "%~dp0.." --export-release "Web"
echo.
echo [exit code %errorlevel%]
