#!/usr/bin/env python3
"""
Script para criar issues de otimização e correções do ClickChannel
Baseado no trabalho realizado em 04/01/2026
"""

import os
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "Click-Channel"  # Corrigido para repo atual

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
formatted_repo_name = REPO_NAME.replace(" ", "-") # Ensure correct formatting if needed
try:
    repo = g.get_user(REPO_OWNER).get_repo(formatted_repo_name)
except:
    # Fallback se o nome for diferente ou user/org
    print(f"Tentando acessar repo {REPO_OWNER}/{REPO_NAME}...")
    try:
        repo = g.get_repo(f"{REPO_OWNER}/{REPO_NAME}")
    except Exception as e:
        print(f"❌ Erro crítico ao acessar repo: {e}")
        exit(1)

# Issues para criação
issues_to_create = [
    {
        "title": "Refatoração de Layout Detalhes para TV (Series & Filmes)",
        "body": """## 📺 Refactoring: Series & Movie Details for TV

### Contexto
O layout anterior usava `LayoutBuilder` complexo e `Stack` com imagens de fundo pesadas, causando:
1. "Bugado" visual (glitches) no Firestick.
2. Crash por falta de memória (OOM).

### Solução Implementada
- [x] Substituição por layout `Row` fixo (Esquerda: Poster/Info, Direita: Conteúdo).
- [x] Remoção de imagens de background (Stack -> Scaffold com fundo preto).
- [x] Implementação de `memCacheWidth` agressivo (140px/240px) para imagens.
- [x] Unificação do design entre Filmes e Séries.

### Status
✅ **Concluído e Implantado** (v1.0.X)
""",
        "labels": ["refactor", "ui/ux", "firestick", "status/done"],
        "close": True 
    },
    {
        "title": "Correção de Crash de Memória (OOM) no Firestick",
        "body": """## 🐛 Bugfix: OutOfMemoryError on Firestick

### Sintoma
O app fechava sozinho (crash silencioso) ao navegar entre 2 ou 3 telas de detalhes de séries/filmes.

### Causa Raiz
O Firestick tem memória RAM limitada (~1GB utilizável). O app mantinha imagens de alta resolução em cache e backgrounds pesados na pilha de navegação.

### Correção Aplicada
- [x] Implementação de `PaintingBinding.instance.imageCache.clear()` e `clearLiveImages()` no `dispose()` das telas.
- [x] Redução da resolução de cache de imagens (`memCacheWidth`).
- [x] Limitação de itens similares carregados (20 -> 10).
- [x] Remoção de `Stack` com imagem de fundo translúcida.

### Status
✅ **Concluído e Validado**
""",
        "labels": ["bug", "performance", "firestick", "urgent", "status/done"],
        "close": True
    },
    {
        "title": "Implementação de Legendas Externas Jellyfin",
        "body": """## ✨ Feature: Jellyfin External Subtitles

### Objetivo
Permitir que o player carregue legendas externas (.srt, .vtt) disponíveis na API do Jellyfin.

### Implementação
- [x] Exposição de getters públicos (`baseUrl`, `accessToken`) no `JellyfinService`.
- [x] Construção manual de URLs de legenda no `MediaPlayerScreen` para evitar erros de build.
- [x] Injeção de legendas via `_player.setSubtitleTrack`.

### Status
✅ **Implementado (Backend/Player Logic)**
""",
        "labels": ["feature", "jellyfin", "media-player", "status/done"],
        "close": True
    },
    {
        "title": "Monitoramento e Estabilidade de Performance Firestick",
        "body": """## 🚀 Estabilização Contínua

### Objetivo
Monitorar o comportamento do aplicativo no Firestick após as otimizações agressivas de memória (Jan 2026).

### Pontos de Atenção
- [ ] Verificar se "travadinhas" na navegação persistem.
- [ ] Monitorar logs para novos OOMs em navegação muito profunda (>10 telas).
- [ ] Validar experiência do usuário com o layout simplificado (sem background).

### Ações Futuras (se necessário)
- Implementar paginação real em listas horizontais.
- Usar isolates para processamento de JSON pesado.

### Status
🔄 **Em Andamento**
""",
        "labels": ["performance", "monitoring", "firestick", "status/in-progress"],
        "close": False
    }
]

print(f"📝 Processando {len(issues_to_create)} issues...\n")

created_count = 0

for issue_data in issues_to_create:
    try:
        # Check if issue already exists (simple title check to avoid dupes in short term)
        # (Skipping check for simplicity in this script run)
        
        issue = repo.create_issue(
            title=issue_data["title"],
            body=issue_data["body"],
            labels=issue_data["labels"]
        )
        print(f"✅ Criada #{issue.number} - {issue_data['title']}")
        
        if issue_data.get("close"):
            issue.edit(state="closed")
            print(f"   (Fechada automaticamente)")
            
        created_count += 1
    except Exception as e:
        print(f"❌ Erro ao criar '{issue_data['title']}': {str(e)}")

print(f"\n✨ Processo finalizado. {created_count} issues processadas.")
