@echo off
REM Wrapper for when ExecutionPolicy blocks running the .ps1 directly.
REM   make_videos.cmd checkout
REM   make_videos.cmd checkout -Lang en -AssembleOnly -Engine wsl
REM All arguments are passed through: it used to pass only the first four, which cut off -Engine after -Lang.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_videos.ps1" -Flow %*
