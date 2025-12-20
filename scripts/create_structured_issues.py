#!/usr/bin/env python3
"""
Script para criar estrutura completa de issues no ClickChannel
Analisa histórico do projeto e cria issues classificadas
"""

import os
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
NEW_REPO_NAME = "ClickChannel"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(NEW_REPO_NAME)

# Estrutura completa de issues desde a criação
issues = [
    # ============ FASE 1: SETUP & INFRASTRUCTURE ============
    {
        "title": "[DONE] Fase 1: Setup & Infrastructure - Projeto criado",
        "body": """## ✅ COMPLETO - Fase 1: Setup & Infrastructure

### O que foi feito:
- [x] Criado novo projeto Flutter
- [x] Estrutura de pastas organizada
- [x] pubspec.yaml configurado
- [x] Dependências base instaladas
- [x] Gitignore e configurações git

### Data de Conclusão: 17/12/2025
""",
        "labels": ["status/done", "priority/alta", "section/infrastructure", "phase/1-setup"]
    },

    # ============ FASE 2: CORE FEATURES ============
    {
        "title": "[DONE] Fase 2: Player com media_kit (4K/HDR)",
        "body": """## ✅ COMPLETO - Player com suporte 4K/HDR

### Implementado:
- [x] Integração media_kit
- [x] Suporte 4K/HDR
- [x] Seleção de faixa de áudio
- [x] Seleção de legendas
- [x] Ajuste de tela (5 modos)
- [x] Controles de TV remote

### Data de Conclusão: 17/12/2025
""",
        "labels": ["status/done", "priority/alta", "section/player", "phase/2-core"]
    },

    {
        "title": "[DONE] Fase 2: Histórico & Continuar Assistindo",
        "body": """## ✅ COMPLETO - Histórico de assistidos

### Implementado:
- [x] Tela "Continuar Assistindo"
- [x] Histórico persistente
- [x] Cache de posição
- [x] Barra de progresso

### Data de Conclusão: 17/12/2025
""",
        "labels": ["status/done", "priority/média", "section/features", "phase/2-core"]
    },

    {
        "title": "[DONE] Fase 2: Filtros de Qualidade",
        "body": """## ✅ COMPLETO - Sistema de Filtros

### Implementado:
- [x] Filtro por qualidade (4K, FHD, HD, SD)
- [x] Persistência de preferência
- [x] UI intuitiva

### Data de Conclusão: 17/12/2025
""",
        "labels": ["status/done", "priority/média", "section/features", "phase/2-core"]
    },

    # ============ FASE 3: ADVANCED FEATURES ============
    {
        "title": "[DONE] Fase 3: EPG (Guia de Programação)",
        "body": """## ✅ COMPLETO - Sistema EPG

### Implementado:
- [x] Parser XMLTV
- [x] Tela de programação por canal
- [x] Indicador "Ao Vivo" / "Em breve"
- [x] Sistema de favoritos de programas
- [x] Configuração de URL EPG em Settings
- [x] Cache de EPG em disco
- [x] EPG mostrado apenas em CANAIS

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/alta", "section/epg", "phase/3-advanced"]
    },

    {
        "title": "[DONE] Fase 3: Agrupamento de Variantes por Canal",
        "body": """## ✅ COMPLETO - Organização por qualidade

### Implementado:
- [x] Agrupamento automático de variantes
- [x] Pastas por canal com múltiplas qualidades
- [x] UI visual para qualidades

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/média", "section/features", "phase/3-advanced"]
    },

    {
        "title": "[DONE] Fase 3: Reset Playlist & Cache",
        "body": """## ✅ COMPLETO - Gerenciamento de Cache

### Implementado:
- [x] Botão Reset em Settings
- [x] Confirmação de ação
- [x] Limpeza total de cache

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/média", "section/features", "phase/3-advanced"]
    },

    {
        "title": "[DONE] Fase 3: Proteção de Primeira Execução",
        "body": """## ✅ COMPLETO - First-run Protection

### Implementado:
- [x] Install marker system
- [x] Evita restauração automática de playlist
- [x] Proteção contra .env vazar

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/alta", "section/security", "phase/3-advanced"]
    },

    # ============ FASE 4: PERFORMANCE ============
    {
        "title": "[DONE] Fase 4: Lazy Loading com Fade-in",
        "body": """## ✅ COMPLETO - Lazy Loading de Imagens

### Implementado:
- [x] Lazy loading automático
- [x] Fade-in animations
- [x] Placeholder shimmer
- [x] Adaptive image sizing

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/alta", "section/performance", "phase/4-perf"]
    },

    {
        "title": "[DONE] Fase 4: Skeleton Loading",
        "body": """## ✅ COMPLETO - Skeleton Loaders

### Implementado:
- [x] Skeleton para carrosséis
- [x] Skeleton para grid
- [x] Animações suaves
- [x] Feedback visual

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/média", "section/performance", "phase/4-perf"]
    },

    {
        "title": "[DONE] Fase 4: Cache 100MB com Limite",
        "body": """## ✅ COMPLETO - Image Cache Management

### Implementado:
- [x] Cache limitado a 100MB
- [x] Limpeza automática
- [x] Priorização de imagens
- [x] Flutter cache manager

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/alta", "section/performance", "phase/4-perf"]
    },

    {
        "title": "[DONE] Fase 4: Compressão de Thumbnails",
        "body": """## ✅ COMPLETO - Image Compression

### Implementado:
- [x] Compressão automática
- [x] Processamento em isolate
- [x] Redimensionamento inteligente
- [x] Sem bloqueio UI

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/média", "section/performance", "phase/4-perf"]
    },

    {
        "title": "[DONE] Fase 4: Paginação Virtual",
        "body": """## ✅ COMPLETO - Virtual Pagination

### Implementado:
- [x] Infinite scroll automático
- [x] Lazy load por chunks
- [x] Suporte a 1000+ items
- [x] Sem travamentos

### Data de Conclusão: 18/12/2025
""",
        "labels": ["status/done", "priority/alta", "section/performance", "phase/4-perf"]
    },

    # ============ FASE 5: FIRESTICK OPTIMIZATION ============
    {
        "title": "[IN PROGRESS] Fase 5: Otimização Firestick",
        "body": """## 🔄 EM ANDAMENTO - Fire Stick Optimizations

### Problema Identificado:
- App trava na tela inicial em Firestick
- Funciona normalmente em Tablet
- Provável causa: memória limitada

### Solução Implementada:
- [x] DeviceOptimizationConfig criado
- [x] Detecção automática de Firestick
- [x] Redução de items iniciais (240 → 50)
- [x] Desabilitar shimmer em low-end
- [x] Desabilitar paginação virtual em Firestick
- [x] Timeouts aumentados

### Status: Testando
""",
        "labels": ["status/in-progress", "priority/alta", "section/firestick", "phase/5-firestick"]
    },

    # ============ ROADMAP FUTURO ============
    {
        "title": "[TODO] Sprint 1: Segurança",
        "body": """## 🔐 Sprint 1: Segurança

### Tarefas:
- [ ] Implementar certificate pinning
- [ ] Migrar credenciais para flutter_secure_storage
- [ ] Audit de dependências

### Prioridade: ALTA
### Estimativa: 2-3 semanas
""",
        "labels": ["status/todo", "priority/alta", "section/security", "sprint/1"]
    },

    {
        "title": "[TODO] Sprint 2: Busca Avançada",
        "body": """## 🔍 Sprint 2: Busca Avançada

### Tarefas:
- [ ] Filtro por ano de lançamento
- [ ] Filtro por gênero
- [ ] Filtro por qualidade (UI melhorada)
- [ ] Histórico de buscas
- [ ] Autocomplete

### Prioridade: MÉDIA
### Estimativa: 2 semanas
""",
        "labels": ["status/todo", "priority/média", "section/search", "sprint/2"]
    },

    {
        "title": "[TODO] Sprint 3: UX/UI Melhorias",
        "body": """## ✨ Sprint 3: UX/UI Enhancements

### Tarefas:
- [ ] Splash screen animada
- [ ] Indicador de loading elegante
- [ ] Feedback sonoro para TV
- [ ] Animações de transição
- [ ] Dark mode refinement

### Prioridade: MÉDIA
### Estimativa: 2 semanas
""",
        "labels": ["status/todo", "priority/média", "section/ux", "sprint/3"]
    },

    {
        "title": "[TODO] Sprint 4: Integração Android TV",
        "body": """## 📺 Sprint 4: Android TV Integration

### Tarefas:
- [ ] Leanback launcher integration
- [ ] Google Voice commands
- [ ] Recomendações na home
- [ ] Channel shortcuts
- [ ] Watch Next integration

### Prioridade: MÉDIA
### Estimativa: 2-3 semanas
""",
        "labels": ["status/todo", "priority/média", "section/androidtv", "sprint/4"]
    },

    {
        "title": "[TODO] Sprint 5: Testes & Qualidade",
        "body": """## 🧪 Sprint 5: Testing & Quality

### Tarefas:
- [ ] Unit tests (coverage > 70%)
- [ ] Widget tests
- [ ] Integration tests
- [ ] Performance benchmarks
- [ ] Firestick compatibility tests

### Prioridade: ALTA
### Estimativa: 3 semanas
""",
        "labels": ["status/todo", "priority/alta", "section/testing", "sprint/5"]
    },

    {
        "title": "[TODO] Futuro: Download Offline",
        "body": """## 💾 Feature: Download para Offline

### Descrição:
- Download de conteúdo para assistir offline
- Limite de armazenamento configurável
- Sincronização automática

### Prioridade: BAIXA
### Estimativa: 3-4 semanas
""",
        "labels": ["status/todo", "priority/baixa", "section/features"]
    },

    {
        "title": "[TODO] Futuro: Chromecast Support",
        "body": """## 📡 Feature: Chromecast/AirPlay

### Descrição:
- Cast para Chromecast
- Cast para AirPlay (iOS)
- Controle remoto durante cast

### Prioridade: BAIXA
### Estimativa: 2 semanas
""",
        "labels": ["status/todo", "priority/baixa", "section/features"]
    },

    {
        "title": "[TODO] Futuro: Múltiplos Perfis",
        "body": """## 👥 Feature: Múltiplos Perfis

### Descrição:
- Criar múltiplos perfis de usuário
- Preferências por perfil
- Histórico separado

### Prioridade: BAIXA
### Estimativa: 2 semanas
""",
        "labels": ["status/todo", "priority/baixa", "section/features"]
    },
]

print(f"📝 Criando {len(issues)} issues estruturadas no ClickChannel...\n")

created = 0
failed = 0

for issue_data in issues:
    try:
        issue = repo.create_issue(
            title=issue_data["title"],
            body=issue_data["body"],
            labels=issue_data["labels"]
        )
        print(f"✅ #{issue.number} - {issue_data['title'][:50]}")
        created += 1
    except Exception as e:
        print(f"❌ Erro: {str(e)}")
        failed += 1

print(f"\n✨ Resumo: {created} issues criadas, {failed} erros")
print(f"\n🎉 Acesse: https://github.com/{REPO_OWNER}/{NEW_REPO_NAME}/issues")
