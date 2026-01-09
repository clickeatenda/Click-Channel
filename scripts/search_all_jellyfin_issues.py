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

print(f"🔍 Buscando TODAS as issues (abertas e fechadas) mencionando 'Jellyfin' em {REPO_NAME}...")

# Busca issues em todos os estados
issues = repo.get_issues(state='all')
found_count = 0

print(f"{'STATUS':<10} | {'ID':<5} | {'TÍTULO'}")
print("-" * 60)

for issue in issues:
    # Verifica título e corpo
    content_to_search = (str(issue.title) + str(issue.body)).lower()
    
    if "jellyfin" in content_to_search:
        status = "🟢 OPEN" if issue.state == "open" else "🔴 CLOSED"
        print(f"{status:<10} | #{issue.number:<5} | {issue.title}")
        found_count += 1

print("-" * 60)
print(f"Total encontrado: {found_count}")
