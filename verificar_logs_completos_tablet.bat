@echo off
set ADB_PATH="C:\Users\joaov\AppData\Local\Android\sdk\platform-tools\adb.exe"
set DEVICE_IP=192.168.3.155:34941

echo ========================================
echo  CAPTURA COMPLETA DE LOGS - TABLET
echo ========================================
echo Dispositivo: %DEVICE_IP%
echo.

echo [1/3] Conectando ao Tablet...
%ADB_PATH% connect %DEVICE_IP%
if errorlevel 1 (
    echo ERRO: Falha ao conectar. Verifique se o dispositivo esta ligado e acessivel.
    pause
    exit /b 1
)
echo OK - Conectado
echo.

echo [2/3] Limpando logs anteriores...
%ADB_PATH% -s %DEVICE_IP% logcat -c
echo OK - Logs limpos
echo.

echo [3/3] Capturando logs em tempo real...
echo ========================================
echo FILTROS ATIVOS:
echo   - main: Inicializacao do app
echo   - TMDB: Enriquecimento TMDB
echo   - CategoryScreen: Carregamento de categoria
echo   - MetaChipsWidget: Exibicao de rating
echo   - Rating: Logs relacionados a rating
echo   - ContentEnricher: Processo de enriquecimento
echo   - AppLogger: Todos os logs estruturados
echo.
echo Pressione Ctrl+C para parar a captura.
echo ========================================
echo.

%ADB_PATH% -s %DEVICE_IP% logcat | findstr /R "main: TMDB CategoryScreen MetaChipsWidget Rating ContentEnricher AppLogger"

pause

