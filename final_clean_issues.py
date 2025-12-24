#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script FINAL para limpar completamente e recriar 60 issues SEM duplicatas
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

print("=== LIMPEZA COMPLETA ===\n")

# PASSO 1: Fechar e contar TODAS as issues
print("Fechando TODAS as issues...\n")
total_closed = 0
for issue in repo.get_issues(state='all'):
    issue.edit(state='closed')
    total_closed += 1

print(f"OK {total_closed} issues fechadas\n")

# PASSO 2: Dados FINAIS - exatamente 60 items, sem repeticoes
issues_final = [
    ("Remover .env do historico do git", "Remover arquivo .env do historico do git", "Alta", "Infrastructure", "Phase 1: Setup & Infrastructure", "done"),
    ("Adicionar .env ao .gitignore", "Configurar .gitignore para ignorar .env", "Alta", "Infrastructure", "Phase 1: Setup & Infrastructure", "done"),
    ("Parser de EPG (XMLTV format)", "Implementar parser para formato XMLTV", "Alta", "Feature", "Phase 3: Advanced Features", "done"),
    ("Tela de programacao por canal", "Criar interface para visualizar programacao", "Alta", "Feature", "Phase 3: Advanced Features", "done"),
    ("Indicador Ao Vivo / Em breve", "Mostrar status ao vivo/em breve dos programas", "Alta", "Feature", "Phase 3: Advanced Features", "done"),
    ("Sistema de favoritos de programas", "Permitir favoritar programas", "Media", "Feature", "Phase 3: Advanced Features", "done"),
    ("Configuracao de URL EPG", "Permitir configurar URL do EPG em Settings", "Alta", "Feature", "Phase 3: Advanced Features", "done"),
    ("Cache de EPG em disco", "Armazenar EPG em cache persistente", "Media", "Performance", "Phase 4: Performance", "done"),
    ("EPG mostrado somente em CANAIS", "Restringir exibicao de EPG apenas na tela de canais", "Media", "Feature", "Phase 3: Advanced Features", "done"),
    ("Notificacao de programa favorito", "Notificar quando programa favorito comeca", "Media", "Feature", "Sprint 2: Search & EPG", "todo"),
    ("Lazy loading de imagens nos cards", "Implementar lazy loading para imagens", "Media", "Performance", "Phase 4: Performance", "done"),
    ("Shimmer skeleton loading nos carrosseis", "Adicionar skeleton loading nos carrosseis", "Media", "Performance", "Phase 4: Performance", "done"),
    ("Cache de imagens com tamanho limitado", "Limitar cache de imagens a 100MB", "Media", "Performance", "Phase 4: Performance", "done"),
    ("Compressao de thumbnails em memoria", "Comprimir thumbnails para economizar memoria", "Media", "Performance", "Phase 4: Performance", "done"),
    ("Paginacao virtual em listas grandes", "Implementar virtual pagination para 1000+ itens", "Media", "Performance", "Phase 4: Performance", "done"),
    ("Migrar credenciais para flutter_secure_storage", "Usar flutter_secure_storage para credenciais", "Alta", "Security", "Sprint 1: Security", "todo"),
    ("Implementar certificate pinning", "Adicionar certificate pinning para API calls", "Alta", "Security", "Sprint 1: Security", "todo"),
    ("Filtro por ano de lancamento", "Permitir filtrar por ano", "Media", "Search", "Sprint 2: Search & EPG", "todo"),
    ("Filtro por genero", "Permitir filtrar por genero", "Media", "Search", "Sprint 2: Search & EPG", "todo"),
    ("Filtro por qualidade", "Permitir filtrar por qualidade (4K, FHD, HD, SD)", "Media", "Search", "Sprint 2: Search & EPG", "todo"),
    ("Historico de buscas recentes", "Manter historico de buscas", "Baixa", "Search", "Sprint 2: Search & EPG", "todo"),
    ("Sugestoes de busca (autocomplete)", "Adicionar autocomplete na busca", "Baixa", "Search", "Sprint 2: Search & EPG", "todo"),
    ("Splash screen animada com logo", "Criar splash screen com animacoes", "Media", "UI", "Sprint 3: UX/UI", "todo"),
    ("Indicador de carregamento elegante", "Melhorar indicador de loading", "Media", "UI", "Sprint 3: UX/UI", "todo"),
    ("Feedback sonoro na navegacao TV", "Adicionar feedback sonoro para TV", "Baixa", "UI", "Sprint 3: UX/UI", "todo"),
    ("Barra de progresso no card Continuar Assistindo", "Mostrar progresso de assistencia", "Media", "UI", "Sprint 3: UX/UI", "todo"),
    ("Animacoes de transicao entre telas", "Adicionar animacoes de transicao", "Baixa", "UI", "Sprint 3: UX/UI", "todo"),
    ("Modo picture in picture (PiP)", "Permitir modo PiP para canais", "Baixa", "Feature", "Phase 3: Advanced Features", "todo"),
    ("Download para assistir offline", "Permitir download de conteudo", "Baixa", "Feature", "Phase 3: Advanced Features", "todo"),
    ("Multiplos perfis de usuario", "Suportar multiplos perfis", "Baixa", "Feature", "Phase 3: Advanced Features", "todo"),
    ("Controle parental com PIN", "Adicionar controle parental", "Baixa", "Feature", "Phase 3: Advanced Features", "todo"),
    ("Legendas externas (.srt .ass .vtt)", "Suportar legendas externas", "Baixa", "Feature", "Phase 3: Advanced Features", "todo"),
    ("Sincronizacao de favoritos na nuvem", "Sincronizar favoritos com cloud", "Baixa", "Feature", "Phase 3: Advanced Features", "todo"),
    ("Cast para Chromecast AirPlay", "Permitir cast para Chromecast/AirPlay", "Baixa", "Feature", "Phase 3: Advanced Features", "todo"),
    ("Reset playlist & cache", "Botao para resetar playlist e cache em Settings", "Media", "Feature", "Phase 3: Advanced Features", "done"),
    ("Agrupamento de variantes por canal", "Agrupar qualidades diferentes por canal", "Media", "Feature", "Phase 3: Advanced Features", "done"),
    ("Integracao com Leanback launcher", "Integrar com Android TV Leanback", "Baixa", "AndroidTV", "Sprint 4: Android TV", "todo"),
    ("Suporte a comandos de voz", "Adicionar suporte a Alexa Google Voice", "Baixa", "AndroidTV", "Sprint 4: Android TV", "todo"),
    ("Recomendacoes na home do Android TV", "Mostrar recomendacoes na home", "Baixa", "AndroidTV", "Sprint 4: Android TV", "todo"),
    ("Channel Shortcuts", "Criar atalhos de canais", "Baixa", "AndroidTV", "Sprint 4: Android TV", "todo"),
    ("Watch Next integration", "Integrar com Watch Next", "Baixa", "AndroidTV", "Sprint 4: Android TV", "todo"),
    ("Testes unitarios (coverage > 70%)", "Implementar testes unitarios com 70%+ coverage", "Media", "Testing", "Sprint 5: Testing", "in-progress"),
    ("Testes de widget", "Criar testes de widget", "Media", "Testing", "Sprint 5: Testing", "todo"),
    ("Retry automatico em falhas de rede", "Implementar retry automatico", "Baixa", "Stability", "Sprint 5: Testing", "todo"),
    ("Reconexao automatica do player", "Reconectar player automaticamente", "Baixa", "Stability", "Sprint 5: Testing", "todo"),
    ("Firebase Crashlytics integration", "Integrar Crashlytics para crashes", "Baixa", "Monitoring", "Sprint 5: Testing", "todo"),
    ("Analytics (Firebase Mixpanel)", "Implementar analytics", "Baixa", "Monitoring", "Sprint 5: Testing", "todo"),
    ("Monitoramento de performance", "Monitorar performance da app", "Baixa", "Monitoring", "Sprint 5: Testing", "todo"),
    ("Testes de performance no Firestick", "Testar performance no Fire Stick", "Alta", "Testing", "Sprint 5: Testing", "todo"),
    ("Player com media_kit (4K HDR)", "Implementar player com suporte 4K/HDR", "Alta", "Core", "Phase 2: Core Features", "done"),
    ("Selecao de faixa de audio", "Permitir selecionar faixa de audio", "Alta", "Core", "Phase 2: Core Features", "done"),
    ("Selecao de legendas", "Permitir selecionar legendas", "Alta", "Core", "Phase 2: Core Features", "done"),
    ("Ajuste de tela (5 modos)", "Implementar 5 modos de ajuste de tela", "Alta", "Core", "Phase 2: Core Features", "done"),
    ("Historico de assistidos", "Manter historico de conteudo assistido", "Media", "Core", "Phase 2: Core Features", "done"),
    ("Continuar assistindo", "Permitir continuar de onde parou", "Media", "Core", "Phase 2: Core Features", "done"),
    ("Filtros de qualidade", "Permitir filtrar por qualidade", "Media", "Core", "Phase 2: Core Features", "done"),
    ("Cache persistente de playlist", "Manter playlist em cache", "Media", "Core", "Phase 2: Core Features", "done"),
    ("Nova logo e icone", "Criar logo e icone atualizados", "Baixa", "Branding", "Phase 2: Core Features", "done"),
    ("Renomeado para Click Channel", "Renomear projeto para Click Channel", "Baixa", "Branding", "Phase 2: Core Features", "done"),
    ("Firestick - Detectar device e otimizar", "Detectar Firestick e aplicar otimizacoes", "Alta", "Optimization", "Phase 5: Firestick Optimization", "in-progress"),
]

# PASSO 3: Obter milestones
milestones = {m.title: m for m in repo.get_milestones(state='all')}

print(f"=== CRIANDO 60 ISSUES LIMPAS ===\n")

created = 0
for nome, desc, prioridade, tipo, milestone_title, status in issues_final:
    try:
        issue = repo.create_issue(title=nome, body=desc)
        
        if status == "done":
            issue.edit(state='closed')
        
        if milestone_title in milestones:
            issue.edit(milestone=milestones[milestone_title])
        
        print(f"OK #{issue.number}")
        created += 1
    except Exception as e:
        print(f"ERRO: {str(e)[:40]}")

print(f"\n=== RESULTADO ===")
print(f"Total de issues criadas: {created}/60")
print(f"\nRepositorio Click-Channel-Final LIMPO e pronto!")
