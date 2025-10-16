@echo off
REM Windows wrapper for the Python build script
REM This allows users to run 'build.bat' on Windows

python build.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed!
    exit /b %ERRORLEVEL%
)

