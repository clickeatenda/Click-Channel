#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para associar issues aos milestones corretos
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
REPO_NAME = "ClickChannel"

if not GITHUB_TOKEN:
    print("GITHUB_TOKEN nao configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

# Mapping de tipo para milestone
milestone_mapping = {
    "Infrastructure": "Phase 1: Setup & Infrastructure",
    "Core": "Phase 2: Core Features",
    "Feature": "Phase 3: Advanced Features",
    "Performance": "Phase 4: Performance",
    "Optimization": "Phase 5: Firestick Optimization",
    "Security": "Sprint 1: Security",
    "Search": "Sprint 2: Search & EPG",
    "UI": "Sprint 3: UX/UI",
    "AndroidTV": "Sprint 4: Android TV",
    "Testing": "Sprint 5: Testing",
    "Stability": "Sprint 5: Testing",
    "Monitoring": "Sprint 5: Testing",
    "Branding": "Phase 2: Core Features",
}

print("Associando issues aos milestones...\n")

# Obter todos os milestones
milestones = {m.title: m for m in repo.get_milestones(state='all')}

updated = 0
for issue in repo.get_issues(state='all'):
    # Extrair tipo do nome ou body
    tipo = None
    
    # Tentar extrair do body (descrição tem o tipo)
    if issue.body:
        for key in milestone_mapping.keys():
            if key.lower() in issue.body.lower():
                tipo = key
                break
    
    # Se não encontrou, tentar pelo padrão do título
    if not tipo:
        for key in milestone_mapping.keys():
            if key.lower() in issue.title.lower():
                tipo = key
                break
    
    # Se encontrou tipo, associar milestone
    if tipo and tipo in milestone_mapping:
        milestone_title = milestone_mapping[tipo]
        if milestone_title in milestones:
            try:
                issue.edit(milestone=milestones[milestone_title])
                print(f"OK #{issue.number} -> {milestone_title}")
                updated += 1
            except Exception as e:
                print(f"ERRO #{issue.number}: {str(e)[:40]}")

print(f"\n{updated} issues associadas aos milestones")
