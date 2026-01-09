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

issue_number = 140

try:
    issue = repo.get_issue(issue_number)
    print(f"Fechando issue #{issue.number}: {issue.title}")
    
    issue.create_comment("✅ Integração com API do Jellyfin concluída e testada.")
    issue.edit(state='closed', labels=['status/done', 'feature/jellyfin'])
    print("Issue fechada com sucesso!")
except Exception as e:
    print(f"Erro ao fechar issue: {e}")
