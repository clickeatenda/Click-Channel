# 📑 Índice de Arquivos - Click Channel Deploy

## 🚀 Scripts de Build e Deploy

### Para Windows (PowerShell)

| Arquivo | Função | Prioridade |
|---------|--------|------------|
| `verificar_antes_build.ps1` | Verifica pré-requisitos | 🔵 Opcional |
| `build_clean.ps1` | Build limpo (sem cache) | 🔴 **OBRIGATÓRIO** |
| `deploy.ps1` | Deploy automático | 🟢 Recomendado |

### Para Linux/Mac (Bash)

| Arquivo | Função | Prioridade |
|---------|--------|------------|
| `verificar_antes_build.sh` | Verifica pré-requisitos | 🔵 Opcional |
| `build_clean.sh` | Build limpo (sem cache) | 🔴 **OBRIGATÓRIO** |
| `deploy.sh` | Deploy automático | 🟢 Recomendado |

---

## 📚 Documentação

### Para Usuários

| Arquivo | Quando Ler | Tempo |
|---------|------------|-------|
| **`COMECE_AQUI.md`** | 🏁 **COMECE POR AQUI!** | 2 min |
| `README_SCRIPTS.md` | Guia completo dos scripts | 10 min |
| `CORRECOES_APLICADAS.md` | Resumo das correções | 5 min |
| `DEPLOYMENT_GUIDE.md` | Deploy manual (avançado) | 15 min |

### Para Desenvolvedores

| Arquivo | Quando Ler | Tempo |
|---------|------------|-------|
| `BUILD_CLEAN_EXPLANATION.md` | Entender problema técnico | 10 min |
| `INDICE_ARQUIVOS.md` | Este arquivo - Índice geral | 3 min |

---

## 🔧 Scripts Python (Automação GitHub)

| Arquivo | Função |
|---------|--------|
| `create_deployment_issue.py` | Criar issue de deployment |
| `update_deployment_issue.py` | Atualizar issue com correções |

---

## 📊 Fluxograma de Leitura

```
┌─────────────────────┐
│  COMECE_AQUI.md     │ ← COMECE AQUI!
│  (2 min)            │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  README_SCRIPTS.md  │ ← Guia completo
│  (10 min)           │
└──────────┬──────────┘
           │
           ├─── Precisa entender o problema? ───┐
           │                                     │
           │                                     ▼
           │                          ┌─────────────────────────┐
           │                          │ BUILD_CLEAN_EXPLANATION │
           │                          │ (10 min)                │
           │                          └─────────────────────────┘
           │
           ├─── Quer fazer deploy manual? ──────┐
           │                                     │
           │                                     ▼
           │                          ┌─────────────────────────┐
           │                          │ DEPLOYMENT_GUIDE.md     │
           │                          │ (15 min)                │
           │                          └─────────────────────────┘
           │
           ▼
   Execute os scripts!
```

---

## 🎯 Ordem de Execução dos Scripts

### Primeiro Deploy (Instalação Inicial)

```
1. verificar_antes_build.ps1  (opcional - verifica setup)
         ↓
2. build_clean.ps1  (OBRIGATÓRIO - build limpo)
         ↓
3. deploy.ps1  (instala nos dispositivos)
```

### Deploy Subsequente (Atualização)

```
1. build_clean.ps1  (se houve mudanças importantes)
         ↓
2. deploy.ps1  (instala nos dispositivos)
```

### Deploy Rápido (APK já existe)

```
deploy.ps1  (apenas instala nos dispositivos)
```

---

## 📱 Configurações dos Dispositivos

Todos os scripts estão configurados com:

- **Fire TV Stick:** 192.168.3.110:5555
- **Tablet Android:** 192.168.3.159:5555

---

## 🔍 Busca Rápida

### Preciso compilar o APK sem cache
→ `build_clean.ps1` / `build_clean.sh`

### Preciso instalar nos dispositivos
→ `deploy.ps1` / `deploy.sh`

### Preciso verificar se está tudo configurado
→ `verificar_antes_build.ps1` / `verificar_antes_build.sh`

### Preciso entender o problema do cache
→ `BUILD_CLEAN_EXPLANATION.md`

### Preciso de um guia completo
→ `README_SCRIPTS.md`

### Primeira vez usando os scripts
→ `COMECE_AQUI.md`

### Preciso fazer deploy manual
→ `DEPLOYMENT_GUIDE.md`

### Preciso ver o que foi corrigido
→ `CORRECOES_APLICADAS.md`

---

## 📊 Tamanho e Complexidade

| Arquivo | Linhas | Complexidade |
|---------|--------|--------------|
| `verificar_antes_build.ps1` | ~150 | 🟢 Simples |
| `build_clean.ps1` | ~100 | 🟢 Simples |
| `deploy.ps1` | ~180 | 🟡 Média |
| `COMECE_AQUI.md` | ~200 | 🟢 Leitura fácil |
| `README_SCRIPTS.md` | ~450 | 🟡 Guia completo |
| `BUILD_CLEAN_EXPLANATION.md` | ~300 | 🟡 Técnico |
| `DEPLOYMENT_GUIDE.md` | ~250 | 🟡 Técnico |

---

## 🔄 Relação Entre Arquivos

```
COMECE_AQUI.md
    ├── README_SCRIPTS.md
    │   ├── verificar_antes_build.ps1/sh
    │   ├── build_clean.ps1/sh
    │   └── deploy.ps1/sh
    │
    ├── BUILD_CLEAN_EXPLANATION.md
    │   └── Explica problema do cache
    │
    ├── CORRECOES_APLICADAS.md
    │   └── Lista correções aplicadas
    │
    └── DEPLOYMENT_GUIDE.md
        └── Deploy manual avançado
```

---

## 🆘 Resolução de Problemas

| Problema | Arquivo para Consultar |
|----------|------------------------|
| Script não executa | `README_SCRIPTS.md` → Troubleshooting |
| Build falha | `BUILD_CLEAN_EXPLANATION.md` |
| Dispositivo não conecta | `DEPLOYMENT_GUIDE.md` → Preparar Dispositivos |
| APK tem dados pré-gravados | `BUILD_CLEAN_EXPLANATION.md` → Solução |
| Não sei por onde começar | `COMECE_AQUI.md` |

---

## ✅ Status dos Arquivos

Todos os arquivos estão:

- ✅ Criados
- ✅ Testados
- ✅ Documentados
- ✅ Prontos para uso

---

## 🔗 Links Externos

- **Issue GitHub:** [#134 - Compilação APK e Instalação](https://github.com/clickeatenda/Click-Channel/issues/134)
- **Repositório:** [Click-Channel](https://github.com/clickeatenda/Click-Channel)

---

## 📅 Histórico de Versões

| Versão | Data | Mudanças |
|--------|------|----------|
| 1.0.0 | 23/12/2024 | Versão inicial completa |
|  |  | - Scripts de build limpo criados |
|  |  | - Scripts de deploy atualizados |
|  |  | - IP do tablet corrigido |
|  |  | - Documentação completa |

---

**Última atualização:** 23/12/2024  
**Versão:** 1.0.0  
**Status:** ✅ Produção

