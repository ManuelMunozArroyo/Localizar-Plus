@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo ==========================================
echo   INSTALADOR DE LOCALIZADOR PLUS
echo ==========================================
echo.

set "DESTINO=%LOCALAPPDATA%\LocalizadorPlus"

REM --- 1. Comprobar si hay Python instalado ---
set PYCMD=
where python >nul 2>nul
if not errorlevel 1 set PYCMD=python
if defined PYCMD goto :python_ok

where py >nul 2>nul
if not errorlevel 1 set PYCMD=py
if defined PYCMD goto :python_ok

echo No encuentro Python instalado en este ordenador.
echo.
echo Instalalo desde la Microsoft Store buscando "Python 3.12",
echo o desde https://www.python.org/downloads/ marcando la casilla
echo "Add python.exe to PATH".
echo Cuando lo tengas, vuelve a ejecutar este instalador.
echo.
pause
exit /b 1

:python_ok
echo Python encontrado, usando: %PYCMD%
echo.

REM --- 2. Cerrar el Localizador si estaba abierto ---
echo Cerrando el Localizador Plus si estaba abierto...
taskkill /f /im "LocalizadorPlus.exe" >nul 2>nul
ping -n 3 127.0.0.1 >nul

REM --- Se quita lo que hubiera de la prueba "Localizador Plus +" (ya no se usa) ---
taskkill /f /im "LocalizadorPlus+.exe" >nul 2>nul
taskkill /f /im "LocalizadorPlusMas.exe" >nul 2>nul
ping -n 2 127.0.0.1 >nul
if exist "%LOCALAPPDATA%\LocalizadorPlus+" rmdir /s /q "%LOCALAPPDATA%\LocalizadorPlus+"
if exist "%LOCALAPPDATA%\LocalizadorPlusMas" rmdir /s /q "%LOCALAPPDATA%\LocalizadorPlusMas"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); Remove-Item -LiteralPath ($d+'\Localizador Plus +.lnk') -ErrorAction SilentlyContinue"

REM --- Se quitan las versiones antiguas del programa en su carpeta ---
if exist "%DESTINO%\LocalizadorPlus.html" del /q "%DESTINO%\LocalizadorPlus.html"
if exist "%DESTINO%\LocalizadorPlus.ico" del /q "%DESTINO%\LocalizadorPlus.ico"

REM --- 3. Copiar el programa ---
echo Copiando el programa...
if not exist "%DESTINO%" mkdir "%DESTINO%"
copy /y "LocalizadorPlus V2.html" "%DESTINO%\" >nul
copy /y "LocalizadorPlus V2.ico" "%DESTINO%\" >nul
if not exist "%DESTINO%\LocalizadorPlus V2.html" goto :error_copia

REM La configuracion de Edge se deja limpia, para que el permiso del
REM microfono se guarde bien desde el principio.
REM (Ya no se borra la carpeta "perfil": ahi guarda Edge tu Excel cargado
REM y el permiso del microfono, y asi no se pierden al actualizar.)

REM --- 4. Preparar lo necesario para compilar ---
echo.
echo Preparando lo necesario, esto puede tardar un par de minutos...
%PYCMD% -m pip install --upgrade pip >nul 2>nul
%PYCMD% -m pip install pyinstaller
echo.

REM --- 5. Compilar el arranque ---
echo Generando LocalizadorPlus.exe, esto tarda 1 o 2 minutos...
echo.
if exist "build" rmdir /s /q "build"
if exist "LocalizadorPlus.spec" del /q "LocalizadorPlus.spec"

%PYCMD% -m PyInstaller --onefile --noconsole --clean --noconfirm --icon "LocalizadorPlus V2.ico" --name "LocalizadorPlus" --distpath "%DESTINO%" "LocalizadorPlus V2.py"

if exist "%DESTINO%\LocalizadorPlus.exe" goto :compilado

echo.
echo ==========================================
echo   ERROR: NO SE HA GENERADO EL PROGRAMA
echo ==========================================
echo Mira los mensajes de arriba para ver que ha fallado
echo y cuentaselo a Claude.
echo.
pause
exit /b 1

:compilado
echo.
echo Programa generado correctamente.
if exist "build" rmdir /s /q "build"
if exist "LocalizadorPlus.spec" del /q "LocalizadorPlus.spec"

REM --- 6. Crear el icono del Escritorio ---
echo Creando el icono del Escritorio...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Localizador Plus.lnk'); $s.TargetPath='%DESTINO%\LocalizadorPlus.exe'; $s.IconLocation='%DESTINO%\LocalizadorPlus V2.ico'; $s.WorkingDirectory='%DESTINO%'; $s.Description='Localizador Plus de las cosas del garaje'; $s.Save()"

powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path ([Environment]::GetFolderPath('Desktop')+'\Localizador Plus.lnk')) { exit 0 } else { exit 1 }"
if errorlevel 1 goto :error_icono

echo.
echo ==========================================
echo   LISTO. Localizador Plus V1 instalado.
echo   Tienes el icono "Localizador Plus" en el Escritorio.
echo.
echo   La primera vez, Edge preguntara si puede usar
echo   el microfono: pulsa PERMITIR. No lo volvera a
echo   preguntar nunca mas.
echo ==========================================
echo.
echo Abriendo Localizador Plus...
start "" "%DESTINO%\LocalizadorPlus.exe"
echo.
pause
exit /b 0

:error_copia
echo.
echo ==========================================
echo   ERROR: NO SE HA PODIDO COPIAR EL PROGRAMA
echo ==========================================
echo Comprueba que has descomprimido la carpeta entera
echo antes de ejecutar este instalador, y vuelve a probar.
echo.
pause
exit /b 1

:error_icono
echo.
echo No se ha podido crear el icono automaticamente.
echo El programa esta instalado igualmente aqui:
echo %DESTINO%
echo Puedes abrirlo con doble clic en LocalizadorPlus.exe de esa carpeta.
echo.
pause
exit /b 1
