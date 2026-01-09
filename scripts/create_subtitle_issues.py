#!/usr/bin/env python3
"""
Script para registrar issues relacionadas às melhorias de legendas e player.
Cria e fecha issues já concluídas e cria issues pendentes.
"""

import os
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "Click-Channel"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

# Lista de labels necessárias
REQUIRED_LABELS = [
    {"name": "status/done", "color": "0E8A16"},
    {"name": "status/in-progress", "color": "FBCA04"},
    {"name": "priority/alta", "color": "D93F0B"},
    {"name": "type/fix", "color": "D73A4A"},
    {"name": "type/feature", "color": "A2EEEF"},
    {"name": "platform/android-tv", "color": "0075ca"}
]

# Garantir que labels existem
print("🏷️ Verificando labels...")
for label_data in REQUIRED_LABELS:
    try:
        repo.get_label(label_data["name"])
    except:
        print(f"➕ Criando label: {label_data['name']}")
        repo.create_label(name=label_data["name"], color=label_data["color"])

issues_data = [
    # --- CONCLUÍDAS ---
    {
        "title": "[FIX] Corrigir erro ao avançar vídeo no player (Seek Bounds Checking)",
        "body": """## 🐛 Bug Fix
### Problema
O app apresentava erro ao tentar avançar o vídeo, pois o player tentava buscar uma posição além da duração total ou antes de estar inicializado.

### Solução
- Implementado `bounds checking` nos métodos `_seekForward` e `_seekBackward`.
- Adicionada verificação `_isInitialized` antes de permitir seek.
- Tratamento de erro `try-catch` para evitar crash.

### Status
✅ Concluído e testado.
""",
        "labels": ["status/done", "type/fix", "priority/alta"],
        "close": True
    },
    {
        "title": "[FEATURE] Implementar preferências de legenda (Tamanho, Cor, Idioma)",
        "body": """## ✨ Nova Feature
### Objetivo
Permitir que o usuário personalize a aparência das legendas.

### Implementação
- Criada classe `Prefs` wrapper para `SharedPreferences`.
- Adicionada seção "Personalização de Legendas" em `SettingsScreen`.
- Opções implementadas:
  - Tamanho (16px - 48px)
  - Cor (Branco, Amarelo, Ciano)
  - Idioma Preferido (PT, EN, ES)

### Status
✅ Concluído.
""",
        "labels": ["status/done", "type/feature", "priority/alta"],
        "close": True
    },
    {
        "title": "[FEATURE] Seleção automática de legenda baseada em idioma",
        "body": """## ✨ Nova Feature
### Objetivo
Selecionar automaticamente a faixa de legenda preferida do usuário ao iniciar um vídeo.

### Implementação
- Criado método `_tryAutoSelectSubtitle` em `MediaPlayerScreen`.
- Lógica verifica:
  1. Preferência do usuário (ex: 'pt').
  2. Varre faixas disponíveis procurando matches (por, pt-br, pob, title contains 'portugues').
  3. Seleciona automaticamente se encontrar.
- Suporta legendas internas e externas (Jellyfin).

### Status
✅ Concluído.
""",
        "labels": ["status/done", "type/feature", "priority/alta"],
        "close": True
    },
    {
        "title": "[FIX] Corrigir erros de build initialization do Prefs",
        "body": """## 🐛 Bug Fix
### Problema
O build falhava ou o app crashava ao iniciar porque `Prefs` era acessado antes de ser inicializado, ou devido a erros de sintaxe.

### Solução
- Movida inicialização de `Prefs` para `main` ou garantida `await Prefs.init()` antes do uso.
- Corrigidos imports faltantes em `media_player_screen.dart`.
- Adicionado tratamento de erro no carregamento de preferências.

### Status
✅ Concluído.
""",
        "labels": ["status/done", "type/fix", "priority/alta"],
        "close": True
    },

    # --- EM ANDAMENTO ---
    {
        "title": "[UX] Melhorar navegação de configuração de legendas para TV (Firestick)",
        "body": """## 📺 UX Improvement
### Problema
O widget `Slider` nativo do Flutter aprisiona o foco de navegação em controles D-pad (TV Remote), impedindo que o usuário saia do seletor de tamanho de legenda.

### Solução Proposta
- Substituir `Slider` por botões manuais `[ - ]` e `[ + ]`.
- Implementar visualização personalizada de barra de progresso.
- Garantir que focos sejam transitáveis via D-pad (Up/Down).

### Status
🚧 Em andamento.
""",
        "labels": ["status/in-progress", "type/fix", "platform/android-tv", "priority/alta"],
        "close": False
    }
]

print(f"\n📝 Processando {len(issues_data)} issues...\n")

for data in issues_data:
    try:
        # Verifica se já existe (simples check pelo título para evitar duplicatas óbvias no run atual)
        # Numa implementação real robusta, buscaria issues abertas, mas aqui vamos criar.
        
        issue = repo.create_issue(
            title=data["title"],
            body=data["body"],
            labels=data["labels"]
        )
        print(f"✅ Criada #{issue.number}: {data['title']}")
        
        if data["close"]:
            issue.edit(state="closed")
            print(f"   Note: Issue fechada como concluída.")
            
    except Exception as e:
        print(f"❌ Erro ao processar '{data['title']}': {e}")

print("\n✨ Processo finalizado!")
