#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para criar 60 issues em formato compatível com Notion
"""

import os
import sys
import json
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

issues_data = [
    {"nome": "Remover .env do historico do git", "descricao": "Remover arquivo .env do historico do git", "prioridade": "Alta", "tipo": "Infrastructure", "status": "done"},
    {"nome": "Adicionar .env ao .gitignore", "descricao": "Configurar .gitignore para ignorar .env", "prioridade": "Alta", "tipo": "Infrastructure", "status": "done"},
    {"nome": "Parser de EPG (XMLTV format)", "descricao": "Implementar parser para formato XMLTV", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Tela de programacao por canal", "descricao": "Criar interface para visualizar programacao", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Indicador Ao Vivo / Em breve", "descricao": "Mostrar status ao vivo/em breve dos programas", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Sistema de favoritos de programas", "descricao": "Permitir favoritar programas", "prioridade": "Media", "tipo": "Feature", "status": "done"},
    {"nome": "Configuracao de URL EPG", "descricao": "Permitir configurar URL do EPG em Settings", "prioridade": "Alta", "tipo": "Feature", "status": "done"},
    {"nome": "Cache de EPG em disco", "descricao": "Armazenar EPG em cache persistente", "prioridade": "Media", "tipo": "Performance", "status": "done"},
    {"nome": "EPG mostrado somente em CANAIS", "descricao": "Restringir exibicao de EPG apenas na tela de canais", "prioridade": "Media", "tipo": "Feature", "status": "done"},
    {"nome": "Notificacao de programa favorito", "descricao": "Notificar quando programa favorito comeca", "prioridade": "Media", "tipo": "Feature", "status": "todo"},
    {"nome": "Lazy loading de imagens nos cards", "descricao": "Implementar lazy loading para imagens", "prioridade": "Media", "tipo": "Performance", "status": "done"},
    {"nome": "Shimmer skeleton loading nos carrosseis", "descricao": "Adicionar skeleton loading nos carrosseis", "prioridade": "Media", "tipo": "Performance", "status": "done"},
    {"nome": "Cache de imagens com tamanho limitado", "descricao": "Limitar cache de imagens a 100MB", "prioridade": "Media", "tipo": "Performance", "status": "done"},
    {"nome": "Compressao de thumbnails em memoria", "descricao": "Comprimir thumbnails para economizar memoria", "prioridade": "Media", "tipo": "Performance", "status": "done"},
    {"nome": "Paginacao virtual em listas grandes", "descricao": "Implementar virtual pagination para 1000+ itens", "prioridade": "Media", "tipo": "Performance", "status": "done"},
    {"nome": "Migrar credenciais para flutter_secure_storage", "descricao": "Usar flutter_secure_storage para credenciais", "prioridade": "Alta", "tipo": "Security", "status": "todo"},
    {"nome": "Implementar certificate pinning", "descricao": "Adicionar certificate pinning para API calls", "prioridade": "Alta", "tipo": "Security", "status": "todo"},
    {"nome": "Filtro por ano de lancamento", "descricao": "Permitir filtrar por ano", "prioridade": "Media", "tipo": "Feature", "status": "todo"},
    {"nome": "Filtro por genero", "descricao": "Permitir filtrar por genero", "prioridade": "Media", "tipo": "Feature", "status": "todo"},
    {"nome": "Filtro por qualidade", "descricao": "Permitir filtrar por qualidade (4K, FHD, HD, SD)", "prioridade": "Media", "tipo": "Feature", "status": "todo"},
    {"nome": "Historico de buscas recentes", "descricao": "Manter historico de buscas", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Sugestoes de busca (autocomplete)", "descricao": "Adicionar autocomplete na busca", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Splash screen animada com logo", "descricao": "Criar splash screen com animacoes", "prioridade": "Media", "tipo": "UI", "status": "todo"},
    {"nome": "Indicador de carregamento elegante", "descricao": "Melhorar indicador de loading", "prioridade": "Media", "tipo": "UI", "status": "todo"},
    {"nome": "Feedback sonoro na navegacao TV", "descricao": "Adicionar feedback sonoro para TV", "prioridade": "Baixa", "tipo": "UI", "status": "todo"},
    {"nome": "Barra de progresso no card Continuar Assistindo", "descricao": "Mostrar progresso de assistencia", "prioridade": "Media", "tipo": "UI", "status": "todo"},
    {"nome": "Animacoes de transicao entre telas", "descricao": "Adicionar animacoes de transicao", "prioridade": "Baixa", "tipo": "UI", "status": "todo"},
    {"nome": "Modo picture in picture (PiP)", "descricao": "Permitir modo PiP para canais", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Download para assistir offline", "descricao": "Permitir download de conteudo", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Multiplos perfis de usuario", "descricao": "Suportar multiplos perfis", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Controle parental com PIN", "descricao": "Adicionar controle parental", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Legendas externas (.srt .ass .vtt)", "descricao": "Suportar legendas externas", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Sincronizacao de favoritos na nuvem", "descricao": "Sincronizar favoritos com cloud", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Cast para Chromecast AirPlay", "descricao": "Permitir cast para Chromecast/AirPlay", "prioridade": "Baixa", "tipo": "Feature", "status": "todo"},
    {"nome": "Reset playlist & cache", "descricao": "Botao para resetar playlist e cache em Settings", "prioridade": "Media", "tipo": "Feature", "status": "done"},
    {"nome": "Agrupamento de variantes por canal", "descricao": "Agrupar qualidades diferentes por canal", "prioridade": "Media", "tipo": "Feature", "status": "done"},
    {"nome": "Integracao com Leanback launcher", "descricao": "Integrar com Android TV Leanback", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Suporte a comandos de voz", "descricao": "Adicionar suporte a Alexa Google Voice", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Recomendacoes na home do Android TV", "descricao": "Mostrar recomendacoes na home", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Channel Shortcuts", "descricao": "Criar atalhos de canais", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Watch Next integration", "descricao": "Integrar com Watch Next", "prioridade": "Baixa", "tipo": "AndroidTV", "status": "todo"},
    {"nome": "Testes unitarios (coverage > 70%)", "descricao": "Implementar testes unitarios com 70%+ coverage", "prioridade": "Media", "tipo": "Testing", "status": "in-progress"},
    {"nome": "Testes de widget", "descricao": "Criar testes de widget", "prioridade": "Media", "tipo": "Testing", "status": "todo"},
    {"nome": "Retry automatico em falhas de rede", "descricao": "Implementar retry automatico", "prioridade": "Baixa", "tipo": "Stability", "status": "todo"},
    {"nome": "Reconexao automatica do player", "descricao": "Reconectar player automaticamente", "prioridade": "Baixa", "tipo": "Stability", "status": "todo"},
    {"nome": "Firebase Crashlytics integration", "descricao": "Integrar Crashlytics para crashes", "prioridade": "Baixa", "tipo": "Monitoring", "status": "todo"},
    {"nome": "Analytics (Firebase Mixpanel)", "descricao": "Implementar analytics", "prioridade": "Baixa", "tipo": "Monitoring", "status": "todo"},
    {"nome": "Monitoramento de performance", "descricao": "Monitorar performance da app", "prioridade": "Baixa", "tipo": "Monitoring", "status": "todo"},
    {"nome": "Testes de performance no Firestick", "descricao": "Testar performance no Fire Stick", "prioridade": "Alta", "tipo": "Testing", "status": "todo"},
    {"nome": "Player com media_kit (4K HDR)", "descricao": "Implementar player com suporte 4K/HDR", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Selecao de faixa de audio", "descricao": "Permitir selecionar faixa de audio", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Selecao de legendas", "descricao": "Permitir selecionar legendas", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Ajuste de tela (5 modos)", "descricao": "Implementar 5 modos de ajuste de tela", "prioridade": "Alta", "tipo": "Core", "status": "done"},
    {"nome": "Historico de assistidos", "descricao": "Manter historico de conteudo assistido", "prioridade": "Media", "tipo": "Core", "status": "done"},
    {"nome": "Continuar assistindo", "descricao": "Permitir continuar de onde parou", "prioridade": "Media", "tipo": "Core", "status": "done"},
    {"nome": "Filtros de qualidade", "descricao": "Permitir filtrar por qualidade", "prioridade": "Media", "tipo": "Core", "status": "done"},
    {"nome": "Cache persistente de playlist", "descricao": "Manter playlist em cache", "prioridade": "Media", "tipo": "Core", "status": "done"},
    {"nome": "Nova logo e icone", "descricao": "Criar logo e icone atualizados", "prioridade": "Baixa", "tipo": "Branding", "status": "done"},
    {"nome": "Renomeado para Click Channel", "descricao": "Renomear projeto para Click Channel", "prioridade": "Baixa", "tipo": "Branding", "status": "done"},
    {"nome": "Firestick - Detectar device e otimizar", "descricao": "Detectar Firestick e aplicar otimizacoes", "prioridade": "Alta", "tipo": "Optimization", "status": "in-progress"},
]

print("Criando 60 issues...\n")

created_issues = []
for issue_data in issues_data:
    try:
        new_issue = repo.create_issue(
            title=issue_data["nome"],
            body=issue_data["descricao"]
        )
        
        if issue_data["status"] == "done":
            new_issue.edit(state='closed')
        
        issue_dict = {
            "nome": issue_data["nome"],
            "descricao": issue_data["descricao"],
            "prioridade": issue_data["prioridade"],
            "status": issue_data["status"],
            "milestone": issue_data["tipo"],
            "tipo_do_projeto": issue_data["tipo"],
            "tipo": issue_data["tipo"],
        }
        
        created_issues.append(issue_dict)
        print(f"OK #{new_issue.number}")
        
    except Exception as e:
        print(f"ERRO: {str(e)[:60]}")

print(f"\n{len(created_issues)} issues criadas")

with open("issues_export.json", 'w', encoding='utf-8') as f:
    json.dump(created_issues, f, ensure_ascii=False, indent=2)

print("Exportado para: issues_export.json")
