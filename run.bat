@echo off
:: Lanzador seguro para PSArkTools - evita errores de ExecutionPolicy
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SoporteTool.ps1" %*
pause