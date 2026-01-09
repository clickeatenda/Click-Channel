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

print(f"🔍 Listando issues ABERTAS em {REPO_NAME}...\n")

issues = repo.get_issues(state='open')
count = 0

print(f"{'ID':<5} | {'TÍTULO'}")
print("-" * 80)

for issue in issues:
    print(f"#{issue.number:<4} | {issue.title}")
    count += 1

print("-" * 80)
print(f"Total de issues abertas: {count}")
