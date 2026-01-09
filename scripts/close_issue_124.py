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

issue_id = 124

try:
    print(f"Buscando issue #{issue_id}...")
    issue = repo.get_issue(issue_id)
    
    print(f"Fechando issue: {issue.title}")
    comment = "✅ Issue fechada conforme solicitação. O aplicativo prioriza o carregamento dinâmico de listas (M3U/Jellyfin)."
    issue.create_comment(comment)
    issue.edit(state="closed", labels=["status/done"])
    
    print("Sucesso!")

except Exception as e:
    print(f"Erro ao fechar issue: {e}")
