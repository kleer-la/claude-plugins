@echo off
REM Wrapper for when ExecutionPolicy blocks running the .ps1 directly.
REM   make_videos.cmd checkout
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_videos.ps1" -Flow %1 %2 %3 %4
