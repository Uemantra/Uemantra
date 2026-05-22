@echo off
title Kitty Tanks Server
color 0A
echo.
echo  ==========================================
echo    KITTY TANKS - Starting Game Server
echo  ==========================================
echo.

cd /d "%~dp0"

where node >nul 2>&1
if %errorlevel% neq 0 (
    echo  ERROR: Node.js is not installed!
    echo.
    echo  Please download and install Node.js from:
    echo  https://nodejs.org/
    echo.
    echo  After installing, close this window and double-click START_SERVER.bat again.
    echo.
    pause
    exit /b 1
)

if not exist node_modules (
    echo  Installing game dependencies (first time only)...
    call npm install
    echo.
)

echo  Starting server...
echo.
node server.js

pause
