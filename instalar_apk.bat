@echo off
REM Script para instalar APK no Firestick via ADB
REM =============================================

setlocal enabledelayedexpansion

set ADB_PATH=C:\Android\sdk\platform-tools\adb.exe
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
set PACKAGE_NAME=com.cliqueatenda.clickechannel
set FIRESTICK_IP=192.168.3.110:5555

echo.
echo ================================================
echo   Instalador APK - Clique Channel (Firestick)
echo ================================================
echo.

REM Verificar se ADB existe
if not exist "%ADB_PATH%" (
    echo [ERRO] ADB nao encontrado em: %ADB_PATH%
    echo.
    echo Tente:
    echo 1. Instalar Android SDK em C:\Android\sdk
    echo 2. Ou usar adb.exe do Flutter:
    echo    flutter pub global activate android_cmd
    echo.
    pause
    exit /b 1
)

REM Verificar se APK existe
if not exist "%APK_PATH%" (
    echo [ERRO] APK nao encontrado em: %APK_PATH%
    echo.
    echo Compile primeiro:
    echo   flutter build apk --release
    echo.
    pause
    exit /b 1
)

echo [PASSO 1] Conectando ao Firestick (%FIRESTICK_IP%)...
"%ADB_PATH%" connect %FIRESTICK_IP%
timeout /t 2 /nobreak

echo.
echo [PASSO 2] Listando dispositivos conectados...
"%ADB_PATH%" devices

echo.
echo [PASSO 3] Desinstalando versao anterior...
"%ADB_PATH%" -s %FIRESTICK_IP% uninstall %PACKAGE_NAME%

echo.
echo [PASSO 4] Instalando novo APK...
echo   Arquivo: %APK_PATH%
echo   Tamanho: ~93.7MB
"%ADB_PATH%" -s %FIRESTICK_IP% install -r "%APK_PATH%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERRO] Falha na instalacao
    pause
    exit /b 1
)

echo.
echo [PASSO 5] Iniciando aplicacao...
"%ADB_PATH%" -s %FIRESTICK_IP% shell am start -n "%PACKAGE_NAME%/.MainActivity"

echo.
echo [PASSO 6] Coletando logs iniciais...
timeout /t 3 /nobreak
echo   Aguarde 10 segundos para coletar logs...
"%ADB_PATH%" -s %FIRESTICK_IP% logcat -s "flutter" "*:V" | find /I "TMDB" | find /I "Lazy"

echo.
echo ================================================
echo   [SUCESSO] Instalacao concluida!
echo ================================================
echo.
echo Verificar no Firestick:
echo   1. Abrir Clique Channel
echo   2. Selecionar um filme
echo   3. Verificar Cast, Director, Budget, Runtime
echo.
echo Para logs completos execute:
echo   adb -s %FIRESTICK_IP% logcat
echo.
pause
