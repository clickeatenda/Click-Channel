#!/usr/bin/env python3
"""
Script para reorganizar issues do ClickChannel com histórico limpo
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

print("🧹 Limpando repositório ClickChannel...\n")

# ============ PASSO 1: FECHAR TODAS AS [DONE] ============
print("📋 PASSO 1: Fechando todas as issues [DONE]...\n")

done_count = 0
for issue in repo.get_issues(state='open'):
    if '[DONE]' in issue.title:
        try:
            issue.edit(state='closed')
            print(f"✅ Fechada: #{issue.number} - {issue.title[:60]}")
            done_count += 1
        except Exception as e:
            print(f"❌ Erro ao fechar #{issue.number}: {str(e)}")

print(f"\n✨ {done_count} issues [DONE] fechadas\n")

# ============ PASSO 2: DELETAR DUPLICATAS ============
print("🔍 PASSO 2: Detectando e fechando duplicatas...\n")

all_issues = list(repo.get_issues(state='open'))
seen_titles = {}
duplicates = []

for issue in all_issues:
    # Normalizar título para comparação
    normalized = issue.title.replace('[IN PROGRESS]', '').replace('[TODO]', '').strip()
    
    if normalized in seen_titles:
        duplicates.append(issue)
        print(f"⚠️  Duplicata encontrada: #{issue.number} - {issue.title[:60]}")
    else:
        seen_titles[normalized] = issue.number

print(f"\n{len(duplicates)} duplicatas encontradas")

if duplicates:
    for dup in duplicates:
        try:
            dup.edit(state='closed')
            print(f"✅ Duplicata fechada: #{dup.number}")
        except Exception as e:
            print(f"❌ Erro: {str(e)}")

# ============ PASSO 3: CRIAR MILESTONES ============
print("\n\n📌 PASSO 3: Criando Milestones...\n")

milestones_data = [
    {"title": "Phase 1: Setup & Infrastructure", "description": "Projeto criado e estruturado"},
    {"title": "Phase 2: Core Features", "description": "Player, histórico, filtros"},
    {"title": "Phase 3: Advanced Features", "description": "EPG, grouping, segurança"},
    {"title": "Phase 4: Performance", "description": "Lazy loading, cache, paginação"},
    {"title": "Phase 5: Firestick Optimization", "description": "Otimização para Fire Stick"},
    {"title": "Sprint 1: Security", "description": "Segurança e credenciais"},
    {"title": "Sprint 2: Search", "description": "Busca avançada"},
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
        created_milestones[ms_data["title"]] = milestone.number
        print(f"✅ Milestone criado: {ms_data['title']}")
    except Exception as e:
        if "already exists" in str(e):
            print(f"⚠️  Milestone já existe: {ms_data['title']}")
            # Tentar obter o milestone existente
            for ms in repo.get_milestones():
                if ms.title == ms_data["title"]:
                    created_milestones[ms_data["title"]] = ms.number
        else:
            print(f"❌ Erro: {str(e)}")

# ============ PASSO 4: ORGANIZAR ISSUES FUTURAS ============
print("\n\n🎯 PASSO 4: Reorganizando issues futuras com Sprints...\n")

future_issues = [
    {
        "title": "[Sprint 1] Segurança - Certificate Pinning",
        "body": "Implementar certificate pinning para API calls",
        "milestone": "Sprint 1: Security"
    },
    {
        "title": "[Sprint 1] Segurança - Credenciais Sensíveis",
        "body": "Migrar credenciais para flutter_secure_storage",
        "milestone": "Sprint 1: Security"
    },
    {
        "title": "[Sprint 2] Busca - Filtros Avançados",
        "body": "Implementar filtros por ano, gênero, qualidade",
        "milestone": "Sprint 2: Search"
    },
    {
        "title": "[Sprint 2] Busca - Histórico e Autocomplete",
        "body": "Histórico de buscas + autocomplete",
        "milestone": "Sprint 2: Search"
    },
    {
        "title": "[Sprint 3] UX/UI - Splash Screen Animada",
        "body": "Implementar splash screen com animações",
        "milestone": "Sprint 3: UX/UI"
    },
    {
        "title": "[Sprint 3] UX/UI - Animações de Transição",
        "body": "Adicionar animações entre telas",
        "milestone": "Sprint 3: UX/UI"
    },
    {
        "title": "[Sprint 4] Android TV - Leanback Integration",
        "body": "Integração com Leanback launcher",
        "milestone": "Sprint 4: Android TV"
    },
    {
        "title": "[Sprint 4] Android TV - Voice Commands",
        "body": "Suporte a comandos de voz (Alexa/Google)",
        "milestone": "Sprint 4: Android TV"
    },
    {
        "title": "[Sprint 5] Testing - Unit Tests",
        "body": "Implementar testes unitários (coverage > 70%)",
        "milestone": "Sprint 5: Testing"
    },
    {
        "title": "[Sprint 5] Testing - Integration Tests",
        "body": "Testes de integração e performance",
        "milestone": "Sprint 5: Testing"
    },
    {
        "title": "[Future] Download Offline",
        "body": "Permitir download de conteúdo para offline",
        "milestone": None
    },
    {
        "title": "[Future] Chromecast/AirPlay Support",
        "body": "Cast para Chromecast e AirPlay",
        "milestone": None
    },
    {
        "title": "[Future] Multiple User Profiles",
        "body": "Suporte a múltiplos perfis de usuário",
        "milestone": None
    },
]

created_future = 0
for issue_data in future_issues:
    try:
        kwargs = {
            "title": issue_data["title"],
            "body": issue_data["body"]
        }
        
        if issue_data["milestone"] and issue_data["milestone"] in created_milestones:
            kwargs["milestone"] = repo.get_milestone(created_milestones[issue_data["milestone"]])
        
        issue = repo.create_issue(**kwargs)
        print(f"✅ Issue criada: #{issue.number} - {issue_data['title']}")
        created_future += 1
    except Exception as e:
        print(f"❌ Erro ao criar '{issue_data['title']}': {str(e)}")

print(f"\n✨ {created_future} issues futuras criadas com Milestones\n")

# ============ RESUMO ============
print("=" * 60)
print("✨ REORGANIZAÇÃO COMPLETA!")
print("=" * 60)
print(f"📌 Milestones criados: {len(created_milestones)}")
print(f"✅ Issues [DONE] fechadas: {done_count}")
print(f"🗑️  Duplicatas fechadas: {len(duplicates)}")
print(f"🎯 Issues futuras com Sprint: {created_future}")
print(f"\n🎉 Repositório limpo e rastreável!")
print(f"   https://github.com/{REPO_OWNER}/{REPO_NAME}/issues")
