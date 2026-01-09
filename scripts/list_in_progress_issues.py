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

print(f"🔍 Buscando issues EM ANDAMENTO em {REPO_NAME}...\n")

issues = repo.get_issues(state='open')
count = 0

print(f"{'ID':<5} | {'TÍTULO'}")
print("-" * 80)

for issue in issues:
    is_in_progress = False
    for label in issue.labels:
        if "progress" in label.name.lower() or "andamento" in label.name.lower():
            is_in_progress = True
            break
    
    if is_in_progress:
        print(f"#{issue.number:<4} | {issue.title}")
        count += 1

print("-" * 80)
print(f"Total de issues em andamento: {count}")
