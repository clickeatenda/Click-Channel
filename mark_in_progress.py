#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para marcar issues como in-progress
"""

import os
import sys
from dotenv import load_dotenv
from github import Github

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "Click-Channel-Final"

if not GITHUB_TOKEN:
    print("GITHUB_TOKEN nao configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

# Issues que devem estar em in-progress
in_progress_titles = [
    "Testes unitarios (coverage > 70%)",
    "Firestick - Detectar device e otimizar"
]

print("Marcando issues como IN-PROGRESS...\n")

count = 0
for issue in repo.get_issues(state='all'):
    if issue.title in in_progress_titles:
        # Garantir que esta aberta
        if issue.state != 'open':
            issue.edit(state='open')
        
        print(f"OK #{issue.number} - {issue.title} (IN-PROGRESS)")
        count += 1

print(f"\nTotal marcadas como in-progress: {count}/2")
