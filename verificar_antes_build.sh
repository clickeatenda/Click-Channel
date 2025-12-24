#!/bin/bash
# Script de Verificação Pré-Build
# Verifica se tudo está correto antes de compilar o APK

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           🔍 VERIFICAÇÃO PRÉ-BUILD                       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

allOk=true

# Verificar Flutter
echo -e "${YELLOW}📱 Verificando Flutter...${NC}"
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}   ✅ Flutter instalado e funcionando${NC}"
else
    echo -e "${RED}   ❌ Flutter não encontrado ou com erro${NC}"
    allOk=false
fi

# Verificar ADB
echo ""
echo -e "${YELLOW}🔧 Verificando ADB...${NC}"
if command -v adb &> /dev/null; then
    echo -e "${GREEN}   ✅ ADB instalado e funcionando${NC}"
else
    echo -e "${RED}   ❌ ADB não encontrado${NC}"
    echo -e "${GRAY}   ℹ️  Instale o Android Platform Tools${NC}"
    allOk=false
fi

# Verificar pubspec.yaml
echo ""
echo -e "${YELLOW}📦 Verificando pubspec.yaml...${NC}"
if [ -f "pubspec.yaml" ]; then
    echo -e "${GREEN}   ✅ pubspec.yaml encontrado${NC}"
else
    echo -e "${RED}   ❌ pubspec.yaml não encontrado${NC}"
    echo -e "${GRAY}   ℹ️  Execute este script no diretório raiz do projeto${NC}"
    allOk=false
fi

# Verificar android/
echo ""
echo -e "${YELLOW}🤖 Verificando diretório Android...${NC}"
if [ -d "android" ]; then
    echo -e "${GREEN}   ✅ Diretório android/ encontrado${NC}"
else
    echo -e "${RED}   ❌ Diretório android/ não encontrado${NC}"
    allOk=false
fi

# Verificar scripts de deploy
echo ""
echo -e "${YELLOW}🚀 Verificando scripts de deploy...${NC}"
if [ -f "deploy.sh" ]; then
    echo -e "${GREEN}   ✅ deploy.sh encontrado${NC}"
else
    echo -e "${YELLOW}   ⚠️  deploy.sh não encontrado${NC}"
fi

if [ -f "build_clean.sh" ]; then
    echo -e "${GREEN}   ✅ build_clean.sh encontrado${NC}"
else
    echo -e "${YELLOW}   ⚠️  build_clean.sh não encontrado${NC}"
fi

# Verificar conectividade com dispositivos
echo ""
echo -e "${YELLOW}📱 Verificando conectividade com dispositivos...${NC}"
echo -e "${GRAY}   (Dispositivos devem estar na mesma rede e com ADB habilitado)${NC}"

# Fire Stick
echo "   • Fire Stick (192.168.3.110)..."
if ping -c 1 -W 1 192.168.3.110 &> /dev/null; then
    echo -e "${GREEN}     ✅ Acessível na rede${NC}"
else
    echo -e "${YELLOW}     ⚠️  Não acessível (verifique se está ligado e na rede)${NC}"
fi

# Tablet
echo "   • Tablet (192.168.3.159)..."
if ping -c 1 -W 1 192.168.3.159 &> /dev/null; then
    echo -e "${GREEN}     ✅ Acessível na rede${NC}"
else
    echo -e "${YELLOW}     ⚠️  Não acessível (verifique se está ligado e na rede)${NC}"
fi

# Verificar se há cache antigo
echo ""
echo -e "${YELLOW}🗑️  Verificando cache antigo...${NC}"
hasCache=false

if [ -d "android/.gradle" ]; then
    echo -e "${YELLOW}   ⚠️  Cache do Gradle encontrado (será removido no build limpo)${NC}"
    hasCache=true
fi

if [ -d "android/build" ]; then
    echo -e "${YELLOW}   ⚠️  Build anterior encontrado (será removido no build limpo)${NC}"
    hasCache=true
fi

if [ -d "build" ]; then
    echo -e "${YELLOW}   ⚠️  Diretório build/ encontrado (será removido no build limpo)${NC}"
    hasCache=true
fi

if [ "$hasCache" = false ]; then
    echo -e "${GREEN}   ✅ Nenhum cache antigo detectado${NC}"
fi

# Resumo final
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

if [ "$allOk" = true ]; then
    echo ""
    echo -e "${GREEN}✅ TUDO PRONTO PARA BUILD!${NC}"
    echo ""
    echo -e "${CYAN}Execute agora:${NC}"
    echo "   1. ./build_clean.sh  (Build limpo)"
    echo "   2. ./deploy.sh       (Deploy automático)"
    echo ""
else
    echo ""
    echo -e "${RED}❌ PROBLEMAS DETECTADOS!${NC}"
    echo ""
    echo -e "${YELLOW}Corrija os itens marcados com ❌ antes de continuar.${NC}"
    echo ""
fi

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

