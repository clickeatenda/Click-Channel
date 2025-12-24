#!/bin/bash
# Script de Deploy - Click Channel
# Compila APK e instala no Fire Stick e Tablet

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
FIRESTICK_IP="192.168.3.110"
TABLET_IP="192.168.3.159"
PORT="5555"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        🚀 DEPLOY CLICK CHANNEL - FIRE STICK & TABLET    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Passo 1: Compilar APK
echo -e "${YELLOW}📦 [1/4] Compilando APK Release...${NC}"
echo -e "${GRAY}      Isso pode levar alguns minutos...${NC}"
echo ""

flutter build apk --release

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Erro na compilação do APK!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ APK compilado com sucesso!${NC}"

# Verificar tamanho do APK
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
    echo -e "${CYAN}📊 Tamanho do APK: $APK_SIZE${NC}"
fi
echo ""

# Passo 2: Conectar dispositivos
echo -e "${YELLOW}🔌 [2/4] Conectando aos dispositivos...${NC}"
echo ""

echo -e "${GRAY}   • Conectando Fire Stick ($FIRESTICK_IP)...${NC}"
adb connect "${FIRESTICK_IP}:${PORT}" > /dev/null 2>&1

echo -e "${GRAY}   • Conectando Tablet ($TABLET_IP)...${NC}"
adb connect "${TABLET_IP}:${PORT}" > /dev/null 2>&1

sleep 2

echo ""
echo -e "${CYAN}📱 Dispositivos conectados:${NC}"
adb devices
echo ""

# Verificar se dispositivos estão conectados
CONNECTED_COUNT=$(adb devices | grep -c "device$")

if [ $CONNECTED_COUNT -lt 2 ]; then
    echo -e "${YELLOW}⚠️  Aviso: Apenas $CONNECTED_COUNT dispositivo(s) conectado(s)${NC}"
    echo -e "${YELLOW}   Verifique se os dispositivos estão ligados e com ADB habilitado${NC}"
    echo ""
    
    read -p "Deseja continuar mesmo assim? (s/N): " continue
    if [ "$continue" != "s" ] && [ "$continue" != "S" ]; then
        echo -e "${RED}Deploy cancelado.${NC}"
        exit 1
    fi
fi

# Passo 3: Instalar no Fire Stick
echo -e "${YELLOW}📲 [3/4] Instalando no Fire Stick...${NC}"
echo -e "${GRAY}      IP: $FIRESTICK_IP${NC}"
echo ""

FIRE_RESULT=$(adb -s "${FIRESTICK_IP}:${PORT}" install -r "$APK_PATH" 2>&1)

if echo "$FIRE_RESULT" | grep -q "Success"; then
    echo -e "${GREEN}✅ Instalado com sucesso no Fire Stick!${NC}"
    FIRE_OK=1
else
    echo -e "${RED}❌ Erro ao instalar no Fire Stick${NC}"
    echo -e "${GRAY}   $FIRE_RESULT${NC}"
    FIRE_OK=0
fi
echo ""

# Passo 4: Instalar no Tablet
echo -e "${YELLOW}📲 [4/4] Instalando no Tablet...${NC}"
echo -e "${GRAY}      IP: $TABLET_IP${NC}"
echo ""

TABLET_RESULT=$(adb -s "${TABLET_IP}:${PORT}" install -r "$APK_PATH" 2>&1)

if echo "$TABLET_RESULT" | grep -q "Success"; then
    echo -e "${GREEN}✅ Instalado com sucesso no Tablet!${NC}"
    TABLET_OK=1
else
    echo -e "${RED}❌ Erro ao instalar no Tablet${NC}"
    echo -e "${GRAY}   $TABLET_RESULT${NC}"
    TABLET_OK=0
fi
echo ""

# Resumo final
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  🎉 DEPLOY CONCLUÍDO! 🎉                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 Resumo:${NC}"
echo -e "   • APK compilado: $APK_SIZE"

echo -n "   • Fire Stick ($FIRESTICK_IP): "
if [ $FIRE_OK -eq 1 ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Erro${NC}"
fi

echo -n "   • Tablet ($TABLET_IP): "
if [ $TABLET_OK -eq 1 ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Erro${NC}"
fi

echo ""
echo -e "${YELLOW}💡 Dica: Abra o app nos dispositivos para testar!${NC}"
echo ""

