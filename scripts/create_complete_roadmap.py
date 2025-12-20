#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para criar TODAS as issues do ROADMAP no ClickChannel
Com estrutura completa: [DONE], [IN PROGRESS], [Sprint 1-5], [Backlog]
"""

import os
import re
import sys
from dotenv import load_dotenv
from github import Github

# Force UTF-8 encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "ClickChannel"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

# Mapping de prioridade
PRIORITY_MAP = {
    "Alta": "priority/alta",
    "Média": "priority/média",
    "Baixa": "priority/baixa"
}

# Issues para criar
issues_to_create = [
    # ============ PRIORIDADE ALTA - SEGURANÇA ============
    {"title": "[DONE] Remover .env do histórico do git", "priority": "Alta", "section": "security", "status": "done"},
    {"title": "[DONE] Adicionar .env ao .gitignore", "priority": "Alta", "section": "security", "status": "done"},
    {"title": "[Sprint 1] Migrar credenciais para flutter_secure_storage", "priority": "Alta", "section": "security", "sprint": 1},
    {"title": "[Sprint 1] Implementar certificate pinning para API calls", "priority": "Alta", "section": "security", "sprint": 1},

    # ============ PRIORIDADE ALTA - EPG ============
    {"title": "[DONE] Parser de EPG (XMLTV format)", "priority": "Alta", "section": "epg", "status": "done"},
    {"title": "[DONE] Tela de programação por canal", "priority": "Alta", "section": "epg", "status": "done"},
    {"title": "[DONE] Indicador 'Ao Vivo' / 'Em breve'", "priority": "Alta", "section": "epg", "status": "done"},
    {"title": "[DONE] Sistema de favoritos de programas", "priority": "Alta", "section": "epg", "status": "done"},
    {"title": "[DONE] Configuração de URL EPG nas Settings", "priority": "Alta", "section": "epg", "status": "done"},
    {"title": "[DONE] Cache de EPG em disco", "priority": "Alta", "section": "epg", "status": "done"},
    {"title": "[DONE] EPG mostrado somente na tela de CANAIS", "priority": "Alta", "section": "epg", "status": "done"},
    {"title": "[Sprint 2] Notificação de programa favorito (local notifications)", "priority": "Alta", "section": "epg", "sprint": 2},

    # ============ PRIORIDADE MÉDIA - PERFORMANCE ============
    {"title": "[DONE] Lazy loading de imagens nos cards", "priority": "Média", "section": "performance", "status": "done"},
    {"title": "[DONE] Shimmer/skeleton loading nos carrosséis", "priority": "Média", "section": "performance", "status": "done"},
    {"title": "[DONE] Cache de imagens com tamanho limitado (100MB max)", "priority": "Média", "section": "performance", "status": "done"},
    {"title": "[DONE] Compressão de thumbnails em memória", "priority": "Média", "section": "performance", "status": "done"},
    {"title": "[DONE] Paginação virtual em listas grandes (+1000 itens)", "priority": "Média", "section": "performance", "status": "done"},

    # ============ PRIORIDADE MÉDIA - BUSCA ============
    {"title": "[Sprint 2] Filtro por ano de lançamento", "priority": "Média", "section": "search", "sprint": 2},
    {"title": "[Sprint 2] Filtro por gênero", "priority": "Média", "section": "search", "sprint": 2},
    {"title": "[Sprint 2] Filtro por qualidade (4K, FHD, HD, SD)", "priority": "Média", "section": "search", "sprint": 2},
    {"title": "[Sprint 2] Histórico de buscas recentes", "priority": "Média", "section": "search", "sprint": 2},
    {"title": "[Sprint 2] Sugestões de busca (autocomplete)", "priority": "Média", "section": "search", "sprint": 2},

    # ============ PRIORIDADE MÉDIA - UX/INTERFACE ============
    {"title": "[Sprint 3] Splash screen animada com logo", "priority": "Média", "section": "ux", "sprint": 3},
    {"title": "[Sprint 3] Indicador de carregamento elegante (shimmer)", "priority": "Média", "section": "ux", "sprint": 3},
    {"title": "[Sprint 3] Feedback sonoro na navegação TV", "priority": "Média", "section": "ux", "sprint": 3},
    {"title": "[Sprint 3] Barra de progresso no card 'Continuar Assistindo'", "priority": "Média", "section": "ux", "sprint": 3},
    {"title": "[Sprint 3] Animações de transição entre telas", "priority": "Média", "section": "ux", "sprint": 3},

    # ============ PRIORIDADE BAIXA - FUNCIONALIDADES EXTRAS ============
    {"title": "[Backlog] Modo picture-in-picture (PiP) para canais", "priority": "Baixa", "section": "features"},
    {"title": "[Backlog] Download para assistir offline", "priority": "Baixa", "section": "features"},
    {"title": "[Backlog] Múltiplos perfis de usuário", "priority": "Baixa", "section": "features"},
    {"title": "[Backlog] Controle parental com PIN", "priority": "Baixa", "section": "features"},
    {"title": "[Backlog] Legendas externas (.srt, .ass, .vtt)", "priority": "Baixa", "section": "features"},
    {"title": "[Backlog] Sincronização de favoritos na nuvem", "priority": "Baixa", "section": "features"},
    {"title": "[Backlog] Cast para Chromecast/AirPlay", "priority": "Baixa", "section": "features"},
    {"title": "[DONE] Reset playlist & cache (botão em Settings)", "priority": "Média", "section": "features", "status": "done"},
    {"title": "[DONE] Agrupamento de variantes por canal", "priority": "Média", "section": "features", "status": "done"},

    # ============ PRIORIDADE BAIXA - ANDROID TV ============
    {"title": "[Sprint 4] Integração com Leanback launcher", "priority": "Baixa", "section": "androidtv", "sprint": 4},
    {"title": "[Sprint 4] Suporte a comandos de voz (Alexa/Google)", "priority": "Baixa", "section": "androidtv", "sprint": 4},
    {"title": "[Sprint 4] Recomendações na home do Android TV", "priority": "Baixa", "section": "androidtv", "sprint": 4},
    {"title": "[Backlog] Channel Shortcuts (atalhos rápidos)", "priority": "Baixa", "section": "androidtv"},
    {"title": "[Backlog] Watch Next integration", "priority": "Baixa", "section": "androidtv"},

    # ============ PRIORIDADE BAIXA - CÓDIGO E ARQUITETURA ============
    {"title": "[IN PROGRESS] Testes unitários (coverage > 70%)", "priority": "Média", "section": "testing", "status": "in-progress"},
    {"title": "[Sprint 5] Testes de widget", "priority": "Baixa", "section": "testing", "sprint": 5},
    {"title": "[Backlog] Migrar para Riverpod ou Bloc", "priority": "Baixa", "section": "architecture"},
    {"title": "[Backlog] Documentação de API inline", "priority": "Baixa", "section": "architecture"},
    {"title": "[Backlog] Tratamento de erros granular", "priority": "Baixa", "section": "architecture"},
    {"title": "[Backlog] Logs estruturados com níveis", "priority": "Baixa", "section": "architecture"},
    {"title": "[DONE] Proteção de primeira execução / install marker", "priority": "Alta", "section": "security", "status": "done"},

    # ============ PRIORIDADE BAIXA - ESTABILIDADE ============
    {"title": "[Sprint 5] Retry automático em falhas de rede", "priority": "Baixa", "section": "stability", "sprint": 5},
    {"title": "[Sprint 5] Reconexão automática do player", "priority": "Baixa", "section": "stability", "sprint": 5},
    {"title": "[Backlog] Firebase Crashlytics integration", "priority": "Baixa", "section": "stability"},
    {"title": "[Backlog] Analytics (Firebase/Mixpanel)", "priority": "Baixa", "section": "stability"},
    {"title": "[Backlog] Monitoramento de performance", "priority": "Baixa", "section": "stability"},

    # ============ PRIORIDADE ALTA - CORE FEATURES (v1.0.0) ============
    {"title": "[DONE] Player com media_kit (4K/HDR)", "priority": "Alta", "section": "core", "status": "done"},
    {"title": "[DONE] Seleção de faixa de áudio", "priority": "Alta", "section": "core", "status": "done"},
    {"title": "[DONE] Seleção de legendas", "priority": "Alta", "section": "core", "status": "done"},
    {"title": "[DONE] Ajuste de tela (5 modos)", "priority": "Alta", "section": "core", "status": "done"},
    {"title": "[DONE] Histórico de assistidos", "priority": "Média", "section": "core", "status": "done"},
    {"title": "[DONE] Continuar assistindo", "priority": "Média", "section": "core", "status": "done"},
    {"title": "[DONE] Filtros de qualidade", "priority": "Média", "section": "core", "status": "done"},
    {"title": "[DONE] Cache persistente de playlist", "priority": "Média", "section": "core", "status": "done"},
    {"title": "[DONE] Nova logo e ícone", "priority": "Baixa", "section": "branding", "status": "done"},
    {"title": "[DONE] Renomeado para Click Channel", "priority": "Baixa", "section": "branding", "status": "done"},

    # ============ FIRESTICK OPTIMIZATION ============
    {"title": "[IN PROGRESS] Firestick: Detectar device e otimizar", "priority": "Alta", "section": "firestick", "status": "in-progress"},
    {"title": "[Sprint 5] Testes de performance no Firestick", "priority": "Alta", "section": "firestick", "sprint": 5},
]

print(f"📝 Criando {len(issues_to_create)} issues completas no ClickChannel...\n")

# Obter milestones
milestones = {m.title: m.number for m in repo.get_milestones()}

created = 0
failed = 0

for issue_data in issues_to_create:
    try:
        labels = [PRIORITY_MAP[issue_data["priority"]], f"section/{issue_data['section']}"]
        
        # Adicionar status/sprint label
        if issue_data.get("status") == "done":
            labels.append("status/done")
        elif issue_data.get("status") == "in-progress":
            labels.append("status/in-progress")
        else:
            labels.append("status/todo")
        
        if "sprint" in issue_data:
            labels.append(f"sprint/{issue_data['sprint']}")
        
        kwargs = {"title": issue_data["title"], "labels": labels}
        
        # Adicionar milestone se for Sprint
        if "sprint" in issue_data:
            sprint_title = f"Sprint {issue_data['sprint']}: {'Security' if issue_data['sprint'] == 1 else 'Search' if issue_data['sprint'] == 2 else 'UX/UI' if issue_data['sprint'] == 3 else 'Android TV' if issue_data['sprint'] == 4 else 'Testing'}"
            for ms_title, ms_num in milestones.items():
                if f"Sprint {issue_data['sprint']}" in ms_title:
                    kwargs["milestone"] = repo.get_milestone(ms_num)
                    break
        
        issue = repo.create_issue(**kwargs)
        
        # Fechar se for [DONE]
        if issue_data.get("status") == "done":
            issue.edit(state='closed')
            print(f"✅ #{issue.number} [CLOSED] - {issue_data['title']}")
        else:
            print(f"✅ #{issue.number} [OPEN] - {issue_data['title']}")
        
        created += 1
    except Exception as e:
        print(f"❌ Erro ao criar '{issue_data['title'][:50]}': {str(e)[:100]}")
        failed += 1

print(f"\n" + "="*60)
print(f"✨ RESULTADO FINAL")
print(f"="*60)
print(f"✅ Issues criadas: {created}")
print(f"❌ Erros: {failed}")
print(f"\n🎉 Repositório ClickChannel completo!")
print(f"   https://github.com/{REPO_OWNER}/{REPO_NAME}/issues")
