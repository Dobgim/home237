@echo off
title Home237 - Local Preview
cd /d "%~dp0"
echo.
echo   ===========================================
echo    Home237 - local preview
echo   ===========================================
echo.
echo    Serving this folder at:  http://localhost:8765
echo.
echo    Your browser will open automatically.
echo    KEEP THIS WINDOW OPEN while testing.
echo    Close it (or press Ctrl+C) to stop the server.
echo.
echo   ===========================================
echo.
start "" "http://localhost:8765/"
python -m http.server 8765 2>nul || py -m http.server 8765
