#!/usr/bin/env python3
"""
Script para atualizar o status das issues no repositório.
Foca em fechar a issue de UX do Firestick que foi concluída.
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

# Issue específica para fechar
ISSUE_NUMBER = 149
ISSUE_TITLE_PART = "Firestick"

try:
    print(f"🔍 Buscando issue #{ISSUE_NUMBER}...")
    issue = repo.get_issue(ISSUE_NUMBER)
    
    if issue.state == "closed":
        print(f"✅ A issue #{ISSUE_NUMBER} já está fechada.")
    else:
        print(f"📝 Atualizando issue #{ISSUE_NUMBER}: {issue.title}")
        issue.create_comment("✅ Implementação concluída! O widget Slider foi substituído por botões manuais (+/-) para garantir melhor navegação com controle remoto.")
        issue.edit(state="closed", labels=["status/done", "type/fix", "platform/android-tv", "priority/alta"])
        print(f"🎉 Issue #{ISSUE_NUMBER} fechada com sucesso!")

except Exception as e:
    print(f"❌ Erro ao atualizar issue: {e}")

print("\n✨ Repositório atualizado.")
