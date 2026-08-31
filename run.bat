@echo off
REM Emberling launcher. All arguments are forwarded to the game.
REM
REM   run.bat                 play
REM   run.bat --bot           self-play (walks the whole loop without a human)
REM   run.bat --floor=5       start at floor 5
REM   run.bat --seed=4242     replay the same dungeon
REM   run.bat --ui=shop       open one screen directly
REM
REM See README.md for the full list.
REM Set GODOT=C:\path\to\Godot.exe if Godot lives somewhere else.
REM
REM NOTE: keep this file ASCII-only. cmd.exe reads .bat in the OEM codepage
REM (949 here), and UTF-8 Korean comments corrupt the parser.

setlocal
if "%GODOT%"=="" set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"

if not exist "%GODOT%" (
  echo Godot not found: %GODOT%
  echo   set GODOT=C:\path\to\Godot.exe
  exit /b 1
)

"%GODOT%" --path "%~dp0." -- %*
endlocal
