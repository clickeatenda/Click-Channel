# GUIA DE INSTALAÇÃO MANUAL NO FIRESTICK
# =====================================

## Opção 1: Via Android Studio / ADB (se configurado)
# 1. Conectar Firestick ao PC via USB ou WiFi
# 2. Executar: adb connect 192.168.3.110:5555
# 3. Instalar: adb install -r ./build/app/outputs/flutter-apk/app-release.apk

## Opção 2: Via Sideload (Fire TV Stick)
# 1. Copiar o APK para Firestick via File Manager ou WeTransfer
# 2. Abrir com "Downloader" app
# 3. Executar e autorizar instalação

## Caminho do APK compilado:
# ./build/app/outputs/flutter-apk/app-release.apk

## Teste após instalação:
# 1. Abrir Clique Channel
# 2. Ir para Settings -> TMDB API Key
# 3. Verificar se acesso não é mais bloqueado pelo EPG
# 4. Abrir um filme e verificar:
#    - Cast carrega dinamicamente abaixo da sinopse
#    - Director, Budget, Revenue aparecem no painel de info
#    - Carregamento é rápido (lazy-load no background)

## Logs para diagnóstico:
adb logcat | grep -E "TMDB|flutter|Lazy-loading"
