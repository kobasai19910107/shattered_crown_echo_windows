@echo off
setlocal
set "PROJECT=%~dp0"
set "GODOT=%~1"
if "%GODOT%"=="" (
  echo Drag your Godot 4 executable onto RUN_STEP22_AUTOTEST.bat.
  echo Or run: RUN_STEP22_AUTOTEST.bat "C:\path\to\godot.exe"
  pause
  exit /b 2
)
if not exist "%GODOT%" (
  echo Godot executable not found: %GODOT%
  pause
  exit /b 2
)
if not exist "%PROJECT%project.godot" (
  echo project.godot is missing.
  pause
  exit /b 2
)
echo Importing... 
"%GODOT%" --headless --path "%PROJECT%" --editor --quit > "%PROJECT%STEP22_import_log.txt" 2>&1
if errorlevel 1 (
  echo Import FAILED. See STEP22_import_log.txt
  pause
  exit /b 1
)
echo Running STEP22 test...
"%GODOT%" --headless --path "%PROJECT%" --script res://ui_trial/tests/step22_battle_smoke.gd > "%PROJECT%STEP22_runtime_log.txt" 2>&1
set "EXITCODE=%errorlevel%"
echo Done. Result code: %EXITCODE%. See STEP22_runtime_log.txt
pause
exit /b %EXITCODE%
