#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para atualizar a Issue #134 com as correções
"""

import os
import sys
from github import Github
from dotenv import load_dotenv
from datetime import datetime

# Fix encoding para Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

def main():
    load_dotenv()
    
    token = os.getenv('GITHUB_TOKEN')
    if not token:
        print("❌ GITHUB_TOKEN não encontrado no .env")
        return
    
    from github import Auth
    auth = Auth.Token(token)
    g = Github(auth=auth)
    repo = g.get_repo("clickeatenda/Click-Channel")
    
    try:
        issue = repo.get_issue(134)
        
        # Comentário com as correções
        comment = f"""## ✅ Correções Aplicadas - {datetime.now().strftime('%d/%m/%Y %H:%M')}

### 🐛 Problema Identificado: APK com Lista M3U Pré-gravada

O APK estava sendo compilado com dados de cache de desenvolvimento, fazendo com que a aplicação não iniciasse limpa.

### 🔧 Solução Implementada

#### 1. Scripts de Build Limpo
Criados scripts que garantem compilação sem cache:

- ✅ `build_clean.ps1` (Windows)
- ✅ `build_clean.sh` (Linux/Mac)

**O que fazem:**
- Remove cache do Gradle e builds anteriores
- Executa `flutter clean`
- Recompila APK release do zero
- Garante que install marker funcionará corretamente

#### 2. IP do Tablet Corrigido
- ❌ IP incorreto: `192.168.3.129`
- ✅ IP correto: `192.168.3.159`

**Arquivos atualizados:**
- `deploy.ps1`
- `deploy.sh`
- `DEPLOYMENT_GUIDE.md`

### 📋 Workflow Atualizado

```powershell
# Passo 1: Build Limpo (NOVO - OBRIGATÓRIO)
./build_clean.ps1

# Passo 2: Deploy Automático
./deploy.ps1
```

### 📱 Dispositivos Configurados

| Dispositivo | IP | Porta | Status |
|-------------|-----|-------|--------|
| Fire TV Stick | 192.168.3.110 | 5555 | ✅ Correto |
| Tablet Android | 192.168.3.159 | 5555 | ✅ Corrigido |

### 📚 Documentação Criada

- ✅ `BUILD_CLEAN_EXPLANATION.md` - Explicação detalhada do problema e solução
- ✅ `build_clean.ps1` - Script de build limpo (Windows)
- ✅ `build_clean.sh` - Script de build limpo (Linux/Mac)
- ✅ Scripts de deploy atualizados com IP correto

### 🎯 Resultado Esperado

Após executar `build_clean.ps1`:
1. ✅ APK compilado sem cache
2. ✅ App inicia na Setup Screen (sem playlist)
3. ✅ Usuário configura playlist manualmente
4. ✅ Install marker funciona corretamente

### 🚀 Próximos Passos

1. Executar `./build_clean.ps1` para gerar APK limpo
2. Executar `./deploy.ps1` para instalar nos dispositivos
3. Verificar se app inicia limpo (sem lista pré-configurada)

---

**Documentação completa:** Consulte `BUILD_CLEAN_EXPLANATION.md` para detalhes técnicos.
"""
        
        issue.create_comment(comment)
        print("\n✅ Issue #134 atualizada com sucesso!")
        print(f"🔗 https://github.com/clickeatenda/Click-Channel/issues/{issue.number}")
        print("\n📝 Comentário adicionado:")
        print("   • Problema do cache identificado e explicado")
        print("   • Scripts de build limpo criados")
        print("   • IP do tablet corrigido")
        print("   • Workflow atualizado")
        print("   • Documentação completa criada")
        
    except Exception as e:
        print(f"❌ Erro ao atualizar issue: {e}")

if __name__ == "__main__":
    main()

