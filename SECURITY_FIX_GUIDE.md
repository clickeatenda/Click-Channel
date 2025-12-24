# 🚨 GUIA DE CORREÇÃO DE SEGURANÇA - URGENTE

## ⚠️ PROBLEMA CRÍTICO DETECTADO

O arquivo `.env` foi encontrado no histórico do Git em **6 commits**:

```
7f46ac6 - fix: otimizar app para Fire Stick
ad16eb2 - fix: garantir que playlist não é restaurada
105f9d4 - Click Channel v1.0 - Renomeado app
286f610 - Merge pull request #2
213607b - Merge remote-tracking branch
c9997f9 - Implementa novo layout Click Channel
```

## 🔥 AÇÃO IMEDIATA NECESSÁRIA

### Passo 1: Fazer backup do repositório

```bash
# Clonar backup
git clone https://github.com/clickeatenda/Click-Channel-Final.git backup-before-cleanup
```

### Passo 2: Remover .env do histórico (COORDENAR COM EQUIPE)

**Opção A: BFG Repo-Cleaner (Recomendado)**

```bash
# 1. Baixar BFG: https://rtyley.github.io/bfg-repo-cleaner/
# 2. Clonar mirror
git clone --mirror https://github.com/clickeatenda/Click-Channel-Final.git

# 3. Executar BFG
java -jar bfg.jar --delete-files .env Click-Channel-Final.git

# 4. Limpar refs e garbage collect
cd Click-Channel-Final.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 5. Force push (CUIDADO!)
git push --force
```

**Opção B: git filter-branch**

```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

git push --force --all
git push --force --tags
```

### Passo 3: Rotacionar TODAS as credenciais

Se o `.env` continha:
- [ ] GITHUB_TOKEN → Revogar e criar novo
- [ ] M3U_PLAYLIST_URL → Trocar URL se contém credenciais
- [ ] BACKEND_URL → Verificar se exposto
- [ ] Quaisquer API keys → Rotacionar TODAS

### Passo 4: Notificar equipe

```
⚠️ AVISO CRÍTICO DE SEGURANÇA

O arquivo .env foi encontrado no histórico público do Git.
TODAS as credenciais precisam ser rotacionadas.

Ações tomadas:
1. [ ] .env removido do histórico
2. [ ] Credenciais rotacionadas
3. [ ] Equipe notificada
4. [ ] .env no .gitignore (JÁ ESTÁ - linha 22)

Data: [DATA]
Responsável: [NOME]
```

## ✅ VERIFICAÇÃO PÓS-LIMPEZA

```bash
# Verificar se .env ainda está no histórico
git log --all --full-history -- ".env"
# Deve retornar vazio

# Verificar .gitignore
cat .gitignore | grep ".env"
# Deve mostrar: .env
```

## 🔐 PREVENÇÃO FUTURA

1. ✅ `.env` já está no `.gitignore` (linha 22)
2. Adicionar pre-commit hook para detectar .env
3. Usar secrets do GitHub Actions para CI/CD
4. Documentar processo de configuração de .env para novos devs

---

**STATUS:** 🔴 CRÍTICO - EXECUTAR IMEDIATAMENTE
**Issue GitHub:** #128

