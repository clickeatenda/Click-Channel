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

print("🔍 Buscando issues abertas relacionadas a 'Jellyfin'...")

issues = repo.get_issues(state='open')
jellyfin_issues = []

for issue in issues:
    if "Jellyfin" in issue.title or "jellyfin" in issue.title:
        print(f"#{issue.number}: {issue.title}")
        jellyfin_issues.append(issue.number)

if not jellyfin_issues:
    print("Nenhuma issue aberta encontrada com 'Jellyfin' no título.")
