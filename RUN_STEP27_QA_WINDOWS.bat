@echo off
setlocal
cd /d "%~dp0"
set "GODOT=%~1"
if "%GODOT%"=="" (
  where godot >nul 2>nul
  if not errorlevel 1 set "GODOT=godot"
)
if "%GODOT%"=="" (
  echo Godot executable not found.
  echo Drag Godot_v4.7.2-stable_win64_console.exe onto this BAT file,
  echo or run: RUN_STEP27_QA_WINDOWS.bat "C:\path\Godot_v4.7.2-stable_win64_console.exe"
  pause
  exit /b 2
)
echo [STEP27] Import resources in Godot 4.7.2...
"%GODOT%" --headless --editor --path "%~dp0" --import
if errorlevel 1 (
  echo [STEP27] Resource import error. Read the Godot output above.
  pause
  exit /b 1
)
echo [STEP27] Run 30 actual Godot tweens and battle layout checks...
"%GODOT%" --headless --path "%~dp0" --script "res://tests/step27_godot_qa_runner.gd"
set "STATUS=%errorlevel%"
echo.
if "%STATUS%"=="0" (echo STEP27 automated test PASSED.) else (echo STEP27 automated test FAILED. See above log.)
echo Report file: %~dp0STEP27_QA_RESULTS.json
pause
exit /b %STATUS%
