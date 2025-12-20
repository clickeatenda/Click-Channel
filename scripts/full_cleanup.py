#!/usr/bin/env python3
"""
Script para LIMPAR COMPLETAMENTE o ClickChannel e recriar do zero
"""

import os
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "ClickChannel"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

print("🧹 LIMPEZA TOTAL DO REPOSITÓRIO ClickChannel...\n")

# ============ PASSO 1: FECHAR TODAS AS ISSUES ABERTAS ============
print("📋 PASSO 1: Fechando TODAS as issues abertas...\n")

open_issues = list(repo.get_issues(state='open'))
closed_count = 0

for issue in open_issues:
    try:
        issue.edit(state='closed')
        print(f"✅ Fechada: #{issue.number} - {issue.title[:60]}")
        closed_count += 1
    except Exception as e:
        print(f"❌ Erro ao fechar #{issue.number}: {str(e)[:50]}")

print(f"\n✨ {closed_count} issues fechadas\n")

# ============ PASSO 2: DELETAR MILESTONES ANTIGOS ============
print("📌 PASSO 2: Deletando milestones antigos...\n")

for milestone in repo.get_milestones(state='all'):
    try:
        milestone.delete()
        print(f"🗑️  Deletado: {milestone.title}")
    except Exception as e:
        print(f"⚠️  Erro: {str(e)[:50]}")

print(f"\n✨ Milestones deletados\n")

# ============ PASSO 3: RECREAR MILESTONES ============
print("📌 PASSO 3: Recriando Milestones...\n")

milestones_data = [
    {"title": "Phase 1: Setup & Infrastructure", "description": "Projeto criado e estruturado"},
    {"title": "Phase 2: Core Features", "description": "Player, histórico, filtros"},
    {"title": "Phase 3: Advanced Features", "description": "EPG, grouping, segurança"},
    {"title": "Phase 4: Performance", "description": "Lazy loading, cache, paginação"},
    {"title": "Phase 5: Firestick Optimization", "description": "Otimização para Fire Stick"},
    {"title": "Sprint 1: Security", "description": "Segurança e credenciais"},
    {"title": "Sprint 2: Search & EPG", "description": "Busca avançada e EPG"},
    {"title": "Sprint 3: UX/UI", "description": "Melhorias de interface"},
    {"title": "Sprint 4: Android TV", "description": "Integração Android TV"},
    {"title": "Sprint 5: Testing", "description": "Testes e qualidade"},
]

created_milestones = {}

for ms_data in milestones_data:
    try:
        milestone = repo.create_milestone(
            title=ms_data["title"],
            description=ms_data["description"]
        )
        created_milestones[ms_data["title"]] = milestone
        print(f"✅ Criado: {ms_data['title']}")
    except Exception as e:
        print(f"❌ Erro: {str(e)[:50]}")

print(f"\n✨ {len(created_milestones)} Milestones recriados\n")

print("=" * 60)
print("✨ REPOSITÓRIO LIMPO E PRONTO PARA RECRIAR ISSUES!")
print("=" * 60)
print(f"\n📌 Milestones disponíveis: {len(created_milestones)}")
print(f"\n🎯 Próximo passo: Rodar create_complete_roadmap.py novamente")
