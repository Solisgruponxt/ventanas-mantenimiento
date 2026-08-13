@echo off
title Sincronizando ventanas de mantenimiento
echo Leyendo Gmail y actualizando el dashboard de ventanas de mantenimiento...
echo Esto puede tardar 1-2 minutos.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\jsolis\Documents\Claude\Ventanas\sync_ventanas.ps1"
echo.
echo Listo. Detalle completo en sync_log.txt
echo Recarga el dashboard en el navegador para ver los cambios.
pause
