#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para criar issues simples e exportar dados estruturados
"""

import os
import sys
import json
from datetime import datetime
from dotenv import load_dotenv
from github import Github

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

# Issues simples (sem Sprint no nome)
issues_simple = [
    # DONE
    {"nome": "Remover .env do histórico do git", "desc": "Remover arquivo .env do histórico do git", "prioridade": "Alta", "tipo": "Infrastructure", "status": "done"},
    {"nome": "Adicionar .env ao .gitignore", "desc": "Configurar .gitignore para ignorar .env", "prioridade": "Alta", "tipo": "Infrastructure", "status": "done"},
    
    # EPG
    {"nome": "Parser de EPG (XMLTV format)", "desc": "Implementar parser para formato XMLTV", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Tela de programação por canal", "desc": "Criar interface para visualizar programação", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Indicador Ao Vivo / Em breve", "desc": "Mostrar status ao vivo/em breve dos programas", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Sistema de favoritos de programas", "desc": "Permitir favoritar programas", "prioridade": "Média", "tipo": "Feature", "status": "done"},
    {"nome": "Configuração de URL EPG", "desc": "Permitir configurar URL do EPG em Settings", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Cache de EPG em disco", "desc": "Armazenar EPG em cache persistente", "prioridade": "Média", "tipo": "Performance", "status": "done"},
    {"nome": "EPG mostrado somente em CANAIS", "desc": "Restringir exibição de EPG apenas na tela de canais", "prioridade": "Média", "tipo": "Feature", "status": "done"},
    {"nome": "Notificação de programa favorito", "desc": "Notificar quando programa favorito começa", "prioridade": "Média", "tipo": "Feature", "status": "todo"},
    
    # PERFORMANCE
    {"nome": "Lazy loading de imagens nos cards", "desc": "Implementar lazy loading para imagens", "prioridade": "Média", "tipo": "Performance", "status": "done"},
    {"nome": "Shimmer/skeleton loading nos carrosséis", "desc": "Adicionar skeleton loading nos carrosséis", "prioridade": "Média", "tipo": "Performance", "status": "done"},
    {"nome": "Cache de imagens com tamanho limitado", "desc": "Limitar cache de imagens a 100MB", "prioridade": "Média", "tipo": "Performance", "status": "done"},
    {"nome": "Compressão de thumbnails em memória", "desc": "Comprimir thumbnails para economizar memória", "prioridade": "Média", "tipo": "Performance", "status": "done"},
    {"nome": "Paginação virtual em listas grandes", "desc": "Implementar virtual pagination para 1000+ itens", "prioridade": "Média", "tipo": "Performance", "status": "done"},
    
    # SECURITY
    {"nome": "Migrar credenciais para flutter_secure_storage", "desc": "Usar flutter_secure_storage para credenciais", "prioridade": "Alta", "tipo": "Security", "status": "todo"},
    {"nome": "Implementar certificate pinning", "desc": "Adicionar certificate pinning para API calls", "prioridade": "Alta", "tipo": "Security", "status": "todo"},
    
    # SEARCH
    {"nome": "Filtro por ano de lançamento", "desc": "Permitir filtrar por ano", "prioridade": "Média", "tipo": "Feature", "status": "todo"},
    {"nome": "Filtro por gênero", "desc": "Permitir filtrar por gênero", "prioridade": "Média", "tipo": "Feature", "status": "todo"},
    {"nome": "Filtro por qualidade", "desc": "Permitir filtrar por qualidade (4K, FHD, HD, SD)", "prioridade": "Média", "tipo": "Feature", "status": "todo"},
    {"nome": "Histórico de buscas recentes", "desc": "Manter histórico de buscas", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Sugestões de busca (autocomplete)", "desc": "Adicionar autocomplete na busca", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    
    # UX/UI
    {"nome": "Splash screen animada com logo", "desc": "Criar splash screen com animações", "prioridade": "Média", "tipo": "UI", "status": "todo"},
    {"nome": "Indicador de carregamento elegante", "desc": "Melhorar indicador de loading", "prioridade": "Média", "tipo": "UI", "status": "todo"},
    {"nome": "Feedback sonoro na navegação TV", "desc": "Adicionar feedback sonoro para TV", "prioridade": "Baixa", "tipo": "UI", "status": "todo"},
    {"nome": "Barra de progresso no card Continuar Assistindo", "desc": "Mostrar progresso de assistência", "prioridade": "Média", "tipo": "UI", "status": "todo"},
    {"nome": "Animações de transição entre telas", "desc": "Adicionar animações de transição", "prioridade": "Baixa", "tipo": "UI", "status": "todo"},
    
    # FEATURES
    {"nome": "Modo picture-in-picture (PiP)", "desc": "Permitir modo PiP para canais", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Download para assistir offline", "desc": "Permitir download de conteúdo", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Múltiplos perfis de usuário", "desc": "Suportar múltiplos perfis", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Controle parental com PIN", "desc": "Adicionar controle parental", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Legendas externas (.srt, .ass, .vtt)", "desc": "Suportar legendas externas", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Sincronização de favoritos na nuvem", "desc": "Sincronizar favoritos com cloud", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Cast para Chromecast/AirPlay", "desc": "Permitir cast para Chromecast/AirPlay", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Reset playlist & cache", "desc": "Botão para resetar playlist e cache em Settings", "prioridade": "Média", "tipo": "Feature", "status": "done"},
    {"nome": "Agrupamento de variantes por canal", "desc": "Agrupar qualidades diferentes por canal", "prioridade": "Média", "tipo": "Feature", "status": "done"},
    
    # ANDROID TV
    {"nome": "Integração com Leanback launcher", "desc": "Integrar com Android TV Leanback", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Suporte a comandos de voz", "desc": "Adicionar suporte a Alexa/Google Voice", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Recomendações na home do Android TV", "desc": "Mostrar recomendações na home", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Channel Shortcuts", "desc": "Criar atalhos de canais", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Watch Next integration", "desc": "Integrar com Watch Next", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    
    # TESTING
    {"nome": "Testes unitários (coverage > 70%)", "desc": "Implementar testes unitários com 70%+ coverage", "prioridade": "Média", "tipo": "Testing", "status": "in-progress"},
    {"nome": "Testes de widget", "desc": "Criar testes de widget", "prioridade": "Média", "tipo": "Testing", "status": "todo"},
    {"nome": "Retry automático em falhas de rede", "desc": "Implementar retry automático", "prioridade": "Baixa", "tipo": "Stability", "status": "todo"},
    {"nome": "Reconexão automática do player", "desc": "Reconectar player automaticamente", "prioridade": "Baixa", "tipo": "Stability", "status": "todo"},
    {"nome": "Firebase Crashlytics integration", "desc": "Integrar Crashlytics para crashes", "prioridade": "Baixa", "tipo": "Monitoring", "status": "todo"},
    {"nome": "Analytics (Firebase/Mixpanel)", "desc": "Implementar analytics", "prioridade": "Baixa", "tipo": "Monitoring", "status": "todo"},
    {"nome": "Monitoramento de performance", "desc": "Monitorar performance da app", "prioridade": "Baixa", "tipo": "Monitoring", "status": "todo"},
    {"nome": "Testes de performance no Firestick", "desc": "Testar performance no Fire Stick", "prioridade": "Alta", "tipo": "Testing", "status": "todo"},
    
    # CORE
    {"nome": "Player com media_kit (4K/HDR)", "desc": "Implementar player com suporte 4K/HDR", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Seleção de faixa de áudio", "desc": "Permitir selecionar faixa de áudio", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Seleção de legendas", "desc": "Permitir selecionar legendas", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Ajuste de tela (5 modos)", "desc": "Implementar 5 modos de ajuste de tela", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Histórico de assistidos", "desc": "Manter histórico de conteúdo assistido", "prioridade": "Média", "tipo": "Core", "status": "done"},
    {"nome": "Continuar assistindo", "desc": "Permitir continuar de onde parou", "prioridade": "Média", "tipo": "Core", "status": "done"},
    {"nome": "Filtros de qualidade", "desc": "Permitir filtrar por qualidade", "prioridade": "Média", "tipo": "Core", "status": "done"},
    {"nome": "Cache persistente de playlist", "desc": "Manter playlist em cache", "prioridade": "Média", "tipo": "Core", "status": "done"},
    {"nome": "Nova logo e ícone", "desc": "Criar logo e ícone atualizados", "prioridade": "Baixa", "tipo": "Branding", "status": "done"},
    {"nome": "Renomeado para Click Channel", "desc": "Renomear projeto para Click Channel", "prioridade": "Baixa", "tipo": "Branding", "status": "done"},
    
    # FIRESTICK
    {"nome": "Firestick - Detectar device e otimizar", "desc": "Detectar Firestick e aplicar otimizações", "prioridade": "Alta", "tipo": "Optimization", "status": "in-progress"},
]

print("📝 Criando issues simples e estruturadas...\n")

# Limpar issues abertas
print("🧹 Fechando issues abertas...")
for issue in repo.get_issues(state='open'):
    issue.edit(state='closed')
print("✅ Fechadas\n")

# Criar novas issues
created_issues = []
for idx, issue_data in enumerate(issues_simple, 1):
    try:
        # Criar issue
        labels = [
            f"priority/{issue_data['prioridade'].lower()}",
            f"type/{issue_data['tipo'].lower()}",
            f"status/{issue_data['status']}"
        ]
        
        new_issue = repo.create_issue(
            title=issue_data["nome"],
            body=issue_data["desc"],
            labels=labels
        )
        
        # Fechar se DONE
        if issue_data["status"] == "done":
            new_issue.edit(state='closed')
        
        # Estruturar dados
        issue_dict = {
            "id": new_issue.number,
            "nome": issue_data["nome"],
            "descricao": issue_data["desc"],
            "git_link": new_issue.html_url,
            "prioridade": issue_data["prioridade"],
            "projeto": "ClickChannel",
            "repositorio": REPO_NAME,
            "status": issue_data["status"],
            "milestone": issue_data["tipo"],
            "tipo_projeto": issue_data["tipo"],
            "data_criacao": new_issue.created_at.isoformat(),
            "data_atualizacao": new_issue.updated_at.isoformat(),
            "data_termino": None if issue_data["status"] != "done" else new_issue.closed_at.isoformat() if new_issue.closed_at else None,
        }
        
        created_issues.append(issue_dict)
        status_text = "[CLOSED]" if issue_data["status"] == "done" else "[OPEN]"
        print(f"✅ #{new_issue.number} {status_text} - {issue_data['nome']}")
        
    except Exception as e:
        print(f"❌ Erro: {str(e)[:60]}")

print(f"\n✨ {len(created_issues)} issues criadas")

# Exportar para JSON
output_file = "issues_export.json"
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(created_issues, f, ensure_ascii=False, indent=2)

print(f"\n📊 Dados exportados para: {output_file}")
print(f"\n🎉 Repositório ClickChannel pronto!")
print(f"   https://github.com/{REPO_OWNER}/{REPO_NAME}/issues")
