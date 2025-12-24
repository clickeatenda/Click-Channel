```markdown
# 🔒 GUIA DE REMEDIAÇÃO - GitHub Token Comprometido

**Data:** 24/12/2025  
**Severidade:** CRÍTICA  
**Token Comprometido:** [REDACTED-GITHUB-TOKEN]  
**Ação Necessária:** IMEDIATA

---

## ⚠️ RESUMO EXECUTIVO

Um **GitHub token real foi encontrado no arquivo `.env`** que estava versionado no Git. Isso significa que qualquer pessoa com acesso ao repositório pode usá-lo para:

- ✗ Ler/escrever em seus repositórios
- ✗ Acessar informações privadas
- ✗ Criar/modificar issues
- ✗ Fazer commits em seu nome

**Ação imediata:** Revogar o token E removê-lo do histórico do Git.

---

## 🚨 PASSO 1: REVOGAR O TOKEN (5 minutos)

### 1.1 Acessar GitHub Settings
```
1. Abrir: https://github.com/settings/tokens
2. Fazer login se necessário
3. Clicar em "Personal access tokens" (ou "Fine-grained tokens")
```

### 1.2 Localizar e Deletar o Token
```
1. Procurar por: [REDACTED-GITHUB-TOKEN]
2. OU procurar por tokens recentes que possam ser o token .env
3. Clicar no ícone de lixeira (🗑️) ou botão "Delete"
4. Confirmar a exclusão
```

**Confirmação:** Token não será mais válido após alguns segundos.

---

## 🔧 PASSO 2: REMOVER DO HISTÓRICO DO GIT (15 minutos)

### Opção A: Usar BFG Repo-Cleaner (Recomendado)

**Vantagem:** Mais rápido e seguro que `git filter-branch`

#### 2.1 Baixar BFG
```bash
# Windows/Mac/Linux
# Download: https://rtyley.github.io/bfg-repo-cleaner/
# Extract JAR para pasta conhecida
```

#### 2.2 Preparar Repositório Limpo
```bash
# Clone um mirror do repositório
git clone --mirror https://github.com/clickeatenda/Click-Channel.git
cd Click-Channel.git
```

#### 2.3 Remover .env do Histórico
```bash
# Substituir CAMINHO com o local do bfg.jar
java -jar CAMINHO/bfg.jar --delete-files .env
```

#### 2.4 Finalizar Limpeza
```bash
git reflog expire --expire=now --all
git gc --aggressive --prune=now
```

#### 2.5 Force Push para o Repositório
```bash
git push --mirror
```

### Opção B: Usar git filter-repo (Alternativa)

```bash
pip install git-filter-repo

cd /caminho/para/seu/repositorio
git filter-repo --invert-paths --path .env
```

### Opção C: Criar Novo Repositório (Nuclear)

Se as opções acima não funcionarem:

```bash
# 1. Criar novo repositório vazio no GitHub
# 2. Clone do repositório antigo
git clone https://github.com/clickeatenda/Click-Channel.git temp-repo
cd temp-repo

# 3. Remover arquivo .env
rm .env
git add .gitignore  # Se tiver .env listado

# 4. Push para novo repositório
git remote set-url origin https://github.com/clickeatenda/Click-Channel-Clean.git
git push --all
git push --tags
```

---

## 🛡️ PASSO 3: ADICIONAR .env AO .gitignore (2 minutos)

```bash
# 1. Abrir arquivo .gitignore
cat .gitignore

# 2. Se não contiver .env, adicionar:
echo "" >> .gitignore
echo "# Variáveis de ambiente (nunca commitar)" >> .gitignore
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore
echo ".env.*.local" >> .gitignore

# 3. Commit
git add .gitignore
git commit -m "chore: Add .env to gitignore to prevent credential leaks"
git push origin main
```

---

## 🔐 PASSO 4: CRIAR NOVO TOKEN (3 minutos)

### 4.1 Acessar Token Settings
```
1. Ir para: https://github.com/settings/tokens
2. Clicar em "Generate new token"
3. Selecionar "Tokens (classic)" OU "Fine-grained tokens"
```

### 4.2 Configurar Permissões Mínimas

**Para desenvolvimento local, usar apenas:**
- ☑️ `repo` (acesso a repositórios)
- ☑️ `read:user` (ler informações do usuário)
- ☑️ `gist` (se usar gists)

**Remover permissões desnecessárias:**
- ☐ `delete_repo`
- ☐ `admin:org_hook`
- ☐ `admin:public_key`

### 4.3 Salvar Token
```
1. Copiar o novo token
2. Guardar em local seguro (password manager)
3. NÃO commitar ou adicionar ao .env versionado
```

---

## ✅ VERIFICAÇÃO DE SEGURANÇA

### Check 1: Token Revogado
```bash
# Tentar usar o token antigo (deve falhar)
curl -H "Authorization: token [REDACTED-GITHUB-TOKEN]" \
  https://api.github.com/user
# Esperado: 401 Bad credentials
```

### Check 2: .env Removido do Histórico
```bash
# Verificar que .env não aparece no histórico
git log --all --full-history -- .env
# Esperado: nenhum resultado (após BFG/filter-repo)
```

### Check 3: .env no .gitignore
```bash
# Confirmar que .env está ignorado
git check-ignore -v .env
# Esperado: .env é ignorado
```

---

## 📝 CHECKLIST PÓS-REMEDIAÇÃO

- [ ] Token revogado em GitHub (verificar em settings)
- [ ] .env removido do histórico do Git (usando BFG)
- [ ] `.gitignore` contém `.env`
- [ ] Novo token criado com permissões limitadas
- [ ] Novo token testado e funcionando
- [ ] Local `.env` criado com novo token (não commitar!)
- [ ] Todos os colaboradores foram notificados
- [ ] CI/CD atualizado com novo token (se aplicável)

---

## 🚨 PRÓXIMOS PASSOS

### Para Todo o Time
1. **Notificar colaboradores** sobre o vazamento
2. **Revogar acesso** se necessário
3. **Auditar commits** feitos com o token comprometido

### Para CI/CD
```yaml
# Se usar GitHub Actions, atualizar secrets
Settings > Secrets and variables > Actions
- Remover token antigo
- Adicionar novo token
```

### Para Aplicação
```dart
// Se usar GITHUB_TOKEN em código:
final token = dotenv.env['GITHUB_TOKEN'];

// Migrar para:
final storage = FlutterSecureStorage();
final token = await storage.read(key: 'GITHUB_TOKEN');
```

---

## 📞 SUPORTE

### Se Encontrar Problemas

**BFG não funciona:**
```bash
# Usar git filter-repo (alternativa)
pip install git-filter-repo
git filter-repo --invert-paths --path .env
```

**Token ainda aparece no histórico:**
```bash
# Verificar com:
git log --all -- .env
git log -S "[REDACTED-GITHUB-TOKEN]"

# Se ainda aparece, fazer novo repositório (opção C)
```

**Colaboradores têm versão antiga:**
```bash
# Eles precisam fazer:
git pull --rebase origin main
# Ou refazer clone após limpeza
```

---

## ✨ TEMPO TOTAL ESTIMADO

| Etapa | Tempo |
|-------|-------|
| Revogar token | 5 min |
| Remover do histórico | 15 min |
| .gitignore | 2 min |
| Novo token | 3 min |
| Verificação | 5 min |
| **TOTAL** | **30 min** |

---

## 📚 Referências

- GitHub Token Security: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
- BFG Repo-Cleaner: https://rtyley.github.io/bfg-repo-cleaner/
- git filter-repo: https://github.com/newren/git-filter-repo
- Git Secrets Scanning: https://docs.github.com/en/code-security/secret-scanning

---

## 🎯 CONCLUSÃO

Após completar estas etapas:

✅ Token comprometido será revogado e inútil  
✅ .env será removido do histórico do Git  
✅ Futuras credenciais estarão protegidas  
✅ Repositório estará seguro para deploy  

---

*Guia atualizado: 24/12/2025*
*Próxima revisão recomendada: 31/12/2025*
```
