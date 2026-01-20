@echo off
REM Windows wrapper for the Python build script
REM This allows users to run 'build.bat' on Windows
REM
REM Usage:
REM   build.bat                     - Build both debug and release
REM   build.bat --release           - Build release only
REM   build.bat --local-arch        - Build for local architecture only (faster)
REM   build.bat --release --local-arch  - Combine options

python build.py %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed!
    exit /b %ERRORLEVEL%
)

