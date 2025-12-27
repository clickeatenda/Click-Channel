@echo off
echo ========================================
echo Verificando logs do TMDB - FIRESTICK
echo ========================================
echo.
echo Limpando logs anteriores...
"C:\Users\joaov\AppData\Local\Android\sdk\platform-tools\adb.exe" -s 192.168.3.110:5555 logcat -c
echo.
echo Aguardando logs... (Pressione Ctrl+C para parar)
echo.
echo Abra uma categoria de filme ou serie no app e observe os logs abaixo:
echo.
"C:\Users\joaov\AppData\Local\Android\sdk\platform-tools\adb.exe" -s 192.168.3.110:5555 logcat | findstr /I "TMDB CategoryScreen MetaChipsWidget Rating INFO DEBUG WARNING"

