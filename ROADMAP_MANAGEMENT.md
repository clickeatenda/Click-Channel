# 📋 Roadmap Management Guide

Este guia explica como converter o `ROADMAP.md` em issues do GitHub e sincronizar com Notion.

## 🔧 Passo 1: Preparar GitHub Token

1. Vá para https://github.com/settings/tokens
2. Crie um novo token com acesso a `repo` (issues)
3. Copie o token
4. Crie um arquivo `.env` na raiz do projeto:

```env
GITHUB_TOKEN=ghp_seu_token_aqui
```

## 🚀 Passo 2: Instalar dependências

```bash
pip install PyGithub python-dotenv
```

## 📤 Passo 3: Executar a conversão

```bash
python scripts/roadmap_to_github_issues.py
```

Isto vai:
- ✅ Ler `ROADMAP.md`
- ✅ Criar um issue no GitHub para cada item
- ✅ Adicionar labels: `priority/*`, `status/*`, `section/*`
- ✅ Evitar duplicatas

## 🔄 Passo 4: Sincronizar com Notion (Automático)

### Opção A: GitHub2Notion (Recomendado)
1. Vá para https://github2notion.com
2. Conecte GitHub + Notion
3. Selecione este repositório
4. Selecione uma Notion database para sincronizar
5. ✅ Pronto! Sincronização automática

### Opção B: Zapier (Mais flexível)
1. Crie uma conta em https://zapier.com
2. Crie um Zap: "GitHub Issue → Notion Database"
3. Configure triggers e ações
4. ✅ Cada novo issue aparece automaticamente no Notion

### Opção C: Make.com (Alternativa)
1. Vá para https://make.com
2. Crie um novo cenário
3. GitHub Issue trigger → Notion append database record
4. Configure e ative

## 📊 Labels do GitHub

Cada issue será marcado com:

| Label | Descrição |
|-------|-----------|
| `priority/alta` | Prioridade Alta |
| `priority/média` | Prioridade Média |
| `priority/baixa` | Prioridade Baixa |
| `status/todo` | Não iniciado |
| `status/in-progress` | Em andamento |
| `status/done` | Concluído |
| `status/blocked` | Bloqueado |
| `section/epg` | Seção EPG |
| `section/performance` | Seção Performance |

## 🎯 Manter sincronizado

Após a primeira conversão:
1. **Atualize o ROADMAP.md** conforme necessário
2. **Rode novamente o script** periodicamente
3. Script evita duplicatas automaticamente
4. Notion sincroniza em tempo real (se GitHub2Notion estiver ativo)

## 📝 Exemplo

Antes:
```markdown
### Performance
- [ ] Lazy loading de imagens nos cards
- [x] Cache de imagens com tamanho limitado (100MB max)
```

Depois (no GitHub Issues):
- Issue #1: "Lazy loading de imagens nos cards" (open, `status/todo`, `priority/média`, `section/performance`)
- Issue #2: "Cache de imagens com tamanho limitado (100MB max)" (closed, `status/done`, `priority/média`, `section/performance`)

## 🔗 Links úteis

- GitHub Issues: https://github.com/clickeatenda/clickflix/issues
- GitHub2Notion: https://github2notion.com
- Zapier: https://zapier.com
- Make.com: https://make.com

---

**Configurado em:** 18/12/2025
