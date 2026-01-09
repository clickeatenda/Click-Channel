@echo off
echo ==========================================
echo PREPARANDO AMBIENTE E COMPILANDO...
echo ==========================================
echo Detectei alteracao nos arquivos de midia.
echo.
echo 1. Limpando cache antigo...
call flutter clean
call flutter pub get

echo.
echo 2. Atualizando Icones do App (baseado no novo logo.png)...
call flutter pub run flutter_launcher_icons

echo.
echo Tentando desinstalar versao antiga (com.example.clickflix) para garantir limpeza de dados...
echo Se o comando 'adb' nao for reconhecido, desinstale manualmente no tablet.
call adb uninstall com.example.clickflix

echo.
echo 3. Compilando e Instalando no Tablet (192.168.3.155:45487)...
echo Isso pode demorar alguns minutos...
call flutter run --release -d 192.168.3.155:45487

echo.
echo Concluido.
pause
