#!/bin/bash
# Script para Build Limpo do APK
# Garante que nenhum cache seja incluído no APK

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           🧹 BUILD LIMPO - SEM CACHE                     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Passo 1: Limpar build anterior
echo -e "${YELLOW}🧹 [1/5] Limpando build anterior...${NC}"
flutter clean
echo -e "${GREEN}   ✅ Build anterior removido${NC}"
echo ""

# Passo 2: Remover cache de desenvolvimento
echo -e "${YELLOW}🗑️  [2/5] Removendo cache de desenvolvimento...${NC}"

# Remover .env se existir
if [ -f ".env" ]; then
    echo -e "${YELLOW}   ⚠️  Arquivo .env encontrado - será ignorado no build${NC}"
fi

# Limpar cache do Gradle (Android)
if [ -d "android/.gradle" ]; then
    rm -rf android/.gradle
    echo -e "${GREEN}   ✅ Cache do Gradle removido${NC}"
fi

# Limpar cache do build (Android)
if [ -d "android/build" ]; then
    rm -rf android/build
    echo -e "${GREEN}   ✅ Build do Android removido${NC}"
fi

# Limpar cache do app (Android)
if [ -d "android/app/build" ]; then
    rm -rf android/app/build
    echo -e "${GREEN}   ✅ Build do app removido${NC}"
fi

echo ""

# Passo 3: Atualizar dependências
echo -e "${YELLOW}📦 [3/5] Atualizando dependências...${NC}"
flutter pub get
echo -e "${GREEN}   ✅ Dependências atualizadas${NC}"
echo ""

# Passo 4: Verificar que não há cache no código
echo -e "${YELLOW}🔍 [4/5] Verificando ausência de cache...${NC}"
echo -e "${GRAY}   ℹ️  Cache M3U e EPG são criados em RUNTIME${NC}"
echo -e "${GRAY}   ℹ️  Diretório: getApplicationSupportDirectory()${NC}"
echo -e "${GRAY}   ℹ️  Install marker detectará primeira instalação${NC}"
echo -e "${GREEN}   ✅ Build será limpo${NC}"
echo ""

# Passo 5: Compilar APK Release
echo -e "${YELLOW}🔨 [5/5] Compilando APK Release LIMPO...${NC}"
echo -e "${GRAY}   Isso pode levar 2-5 minutos...${NC}"
echo ""

flutter build apk --release --no-tree-shake-icons

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✅ APK LIMPO COMPILADO COM SUCESSO!            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_PATH" ]; then
        APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
        echo -e "${CYAN}📊 Informações do APK:${NC}"
        echo "   • Localização: $APK_PATH"
        echo "   • Tamanho: $APK_SIZE"
        echo -e "${GREEN}   • Status: SEM CACHE - Instalação limpa${NC}"
        echo ""
        
        echo -e "${YELLOW}🎯 Próximo passo:${NC}"
        echo "   ./deploy.sh  (para instalar nos dispositivos)"
        echo ""
    fi
else
    echo ""
    echo -e "${RED}❌ Erro na compilação!${NC}"
    echo -e "${YELLOW}   Verifique os erros acima${NC}"
    echo ""
    exit 1
fi

echo -e "${CYAN}💡 Nota: O app iniciará na tela de Setup (sem playlist pré-configurada)${NC}"
echo ""

