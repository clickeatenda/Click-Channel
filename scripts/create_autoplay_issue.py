#!/usr/bin/env python3
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

issue_title = "[FEATURE] Implementar reprodução contínua de episódios (Autoplay)"
issue_body = """## ✨ Feature Request: Autoplay de Séries

### Objetivo
Permitir que o próximo episódio de uma série seja reproduzido automaticamente assim que o atual terminar, melhorando a experiência de "maratona" (binge-watching).

### Requisitos Funcionais
1.  **Detecção de Fim de Vídeo:** O player deve detectar quando o vídeo termina (`_onVideoCompleted`).
2.  **Identificação do Próximo:** Verificar na playlist ou temporada se existe um episódio subsequente.
3.  **UI de Contagem Regressiva:**
    *   Exibir uma sobreposição (overlay) ao final do vídeo.
    *   Mostrar botão "Próximo Episódio" e um contador (ex: "Tocando em 15s").
    *   Botão "Cancelar" para voltar aos detalhes da série.
4.  **Integração Jellyfin/M3U:** A lógica deve funcionar tanto para a playlist local M3U quanto para itens vindos do Jellyfin.

### Critérios de Aceitação
- [ ] Ao terminar ep. 1, sugere ep. 2.
- [ ] Se for o último ep. da temporada, sugere ep. 1 da próxima (se disponível) ou volta.
- [ ] Opção nas configurações para ativar/desativar Autoplay.

### Prioridade
MÉDIA
"""
labels = ["type/feature", "status/todo", "priority/média"]

try:
    print(f"Criando issue: {issue_title}")
    issue = repo.create_issue(title=issue_title, body=issue_body, labels=labels)
    print(f"✅ Issue criada com sucesso: #{issue.number}")
    print(f"🔗 Link: {issue.html_url}")
except Exception as e:
    print(f"❌ Erro ao criar issue: {e}")
