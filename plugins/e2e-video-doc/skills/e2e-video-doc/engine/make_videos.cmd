@echo off
REM Envoltorio para cuando ExecutionPolicy bloquea correr el .ps1 directo.
REM   make_videos.cmd alta
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_videos.ps1" -Flow %1 %2 %3
