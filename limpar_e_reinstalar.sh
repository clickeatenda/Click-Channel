#!/bin/bash
# Script para Limpar Instalação Anterior e Reinstalar Limpo
# Remove completamente o app e reinstala do zero

TABLET_IP="192.168.3.159"
PORT="5555"
PACKAGE="com.clickeatenda.clickchannel"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║     🗑️  LIMPEZA COMPLETA E REINSTALAÇÃO LIMPA           ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  ATENÇÃO: Isso vai remover TODOS os dados do app!${NC}"
echo ""

# Verificar se APK existe
if [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}❌ APK não encontrado!${NC}"
    echo -e "${YELLOW}   Execute primeiro: ./build_clean.sh${NC}"
    echo ""
    exit 1
fi

# Passo 1: Conectar ao tablet
echo -e "${YELLOW}📱 [1/4] Conectando ao tablet...${NC}"
adb connect "$TABLET_IP:$PORT" > /dev/null 2>&1

if adb devices | grep -q "$TABLET_IP:$PORT"; then
    echo -e "${GREEN}   ✅ Tablet conectado ($TABLET_IP)${NC}"
else
    echo -e "${RED}   ❌ Não foi possível conectar ao tablet${NC}"
    echo -e "${YELLOW}   Verifique se o tablet está:${NC}"
    echo "      • Ligado"
    echo "      • Na mesma rede Wi-Fi"
    echo "      • Com ADB habilitado"
    echo ""
    exit 1
fi

echo ""

# Passo 2: Desinstalar completamente
echo -e "${YELLOW}🗑️  [2/4] Removendo instalação anterior...${NC}"
uninstall_output=$(adb -s "$TABLET_IP:$PORT" uninstall $PACKAGE 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ App removido completamente (incluindo dados)${NC}"
    echo -e "${GRAY}   ℹ️  Cache, preferências e playlists foram deletados${NC}"
else
    if echo "$uninstall_output" | grep -q "not installed"; then
        echo -e "${GRAY}   ℹ️  App não estava instalado (ok)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Erro ao desinstalar: $uninstall_output${NC}"
    fi
fi

echo ""

# Passo 3: Limpar cache adicional
echo -e "${YELLOW}🧹 [3/4] Limpando cache do sistema...${NC}"
adb -s "$TABLET_IP:$PORT" shell "rm -rf /sdcard/Android/data/$PACKAGE" 2>&1 > /dev/null
adb -s "$TABLET_IP:$PORT" shell "rm -rf /data/data/$PACKAGE" 2>&1 > /dev/null
echo -e "${GREEN}   ✅ Cache do sistema limpo${NC}"

echo ""

# Passo 4: Instalar versão limpa
echo -e "${YELLOW}📲 [4/4] Instalando versão LIMPA do app...${NC}"
echo -e "${GRAY}   Aguarde...${NC}"

if adb -s "$TABLET_IP:$PORT" install "$APK_PATH" 2>&1; then
    echo -e "${GREEN}   ✅ App instalado com sucesso!${NC}"
else
    echo -e "${RED}   ❌ Erro na instalação${NC}"
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ REINSTALAÇÃO LIMPA CONCLUÍDA!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📱 Tablet: $TABLET_IP${NC}"
echo ""
echo -e "${YELLOW}✨ O que foi feito:${NC}"
echo -e "${GREEN}   ✅ App anterior removido completamente${NC}"
echo -e "${GREEN}   ✅ Todos os dados e cache limpos${NC}"
echo -e "${GREEN}   ✅ Playlists antigas deletadas${NC}"
echo -e "${GREEN}   ✅ App novo instalado do zero${NC}"
echo ""
echo -e "${CYAN}🎯 Próximo passo:${NC}"
echo "   1. Abra o app no tablet"
echo "   2. Deve mostrar a SETUP SCREEN (sem playlist)"
echo "   3. Configure sua playlist atual"
echo ""
echo -e "${YELLOW}💡 Se ainda aparecer lista antiga:${NC}"
echo "   O problema está no APK (build com cache)"
echo "   Execute: ./build_clean.sh"
echo "   Depois: ./limpar_e_reinstalar.sh"
echo ""

