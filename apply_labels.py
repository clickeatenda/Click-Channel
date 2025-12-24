#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para ajustar labels das 60 issues seguindo padrão correto
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

# Mapping de titulo para labels corretos
issue_labels_map = {
    "Remover .env do historico do git": ["Aplicacao Mobile", "tarefa", "alta"],
    "Adicionar .env ao .gitignore": ["Aplicacao Mobile", "tarefa", "alta"],
    "Parser de EPG (XMLTV format)": ["Aplicacao Mobile", "feature", "alta"],
    "Tela de programacao por canal": ["Aplicacao Mobile", "feature", "alta"],
    "Indicador Ao Vivo / Em breve": ["Aplicacao Mobile", "feature", "alta"],
    "Sistema de favoritos de programas": ["Aplicacao Mobile", "feature", "media"],
    "Configuracao de URL EPG": ["Aplicacao Mobile", "feature", "alta"],
    "Cache de EPG em disco": ["Aplicacao Mobile", "melhoria", "media"],
    "EPG mostrado somente em CANAIS": ["Aplicacao Mobile", "melhoria", "media"],
    "Notificacao de programa favorito": ["Aplicacao Mobile", "feature", "media"],
    "Lazy loading de imagens nos cards": ["Aplicacao Mobile", "melhoria", "media"],
    "Shimmer skeleton loading nos carrosseis": ["Aplicacao Mobile", "melhoria", "media"],
    "Cache de imagens com tamanho limitado": ["Aplicacao Mobile", "melhoria", "media"],
    "Compressao de thumbnails em memoria": ["Aplicacao Mobile", "melhoria", "media"],
    "Paginacao virtual em listas grandes": ["Aplicacao Mobile", "melhoria", "media"],
    "Migrar credenciais para flutter_secure_storage": ["Aplicacao Mobile", "melhoria", "alta"],
    "Implementar certificate pinning": ["Aplicacao Mobile", "melhoria", "alta"],
    "Filtro por ano de lancamento": ["Aplicacao Mobile", "feature", "media"],
    "Filtro por genero": ["Aplicacao Mobile", "feature", "media"],
    "Filtro por qualidade": ["Aplicacao Mobile", "feature", "media"],
    "Historico de buscas recentes": ["Aplicacao Mobile", "feature", "baixa"],
    "Sugestoes de busca (autocomplete)": ["Aplicacao Mobile", "feature", "baixa"],
    "Splash screen animada com logo": ["Aplicacao Mobile", "feature", "media"],
    "Indicador de carregamento elegante": ["Aplicacao Mobile", "melhoria", "media"],
    "Feedback sonoro na navegacao TV": ["Aplicacao Mobile", "feature", "baixa"],
    "Barra de progresso no card Continuar Assistindo": ["Aplicacao Mobile", "feature", "media"],
    "Animacoes de transicao entre telas": ["Aplicacao Mobile", "feature", "baixa"],
    "Modo picture in picture (PiP)": ["Aplicacao Mobile", "feature", "baixa"],
    "Download para assistir offline": ["Aplicacao Mobile", "feature", "baixa"],
    "Multiplos perfis de usuario": ["Aplicacao Mobile", "feature", "baixa"],
    "Controle parental com PIN": ["Aplicacao Mobile", "feature", "baixa"],
    "Legendas externas (.srt .ass .vtt)": ["Aplicacao Mobile", "feature", "baixa"],
    "Sincronizacao de favoritos na nuvem": ["Aplicacao Mobile", "feature", "baixa"],
    "Cast para Chromecast AirPlay": ["Aplicacao Mobile", "feature", "baixa"],
    "Reset playlist & cache": ["Aplicacao Mobile", "tarefa", "media"],
    "Agrupamento de variantes por canal": ["Aplicacao Mobile", "melhoria", "media"],
    "Integracao com Leanback launcher": ["Aplicacao Mobile", "feature", "baixa"],
    "Suporte a comandos de voz": ["Aplicacao Mobile", "feature", "baixa"],
    "Recomendacoes na home do Android TV": ["Aplicacao Mobile", "feature", "baixa"],
    "Channel Shortcuts": ["Aplicacao Mobile", "feature", "baixa"],
    "Watch Next integration": ["Aplicacao Mobile", "feature", "baixa"],
    "Testes unitarios (coverage > 70%)": ["Aplicacao Mobile", "tarefa", "media", "em andamento"],
    "Testes de widget": ["Aplicacao Mobile", "tarefa", "media"],
    "Retry automatico em falhas de rede": ["Aplicacao Mobile", "melhoria", "baixa"],
    "Reconexao automatica do player": ["Aplicacao Mobile", "melhoria", "baixa"],
    "Firebase Crashlytics integration": ["Aplicacao Mobile", "feature", "baixa"],
    "Analytics (Firebase Mixpanel)": ["Aplicacao Mobile", "feature", "baixa"],
    "Monitoramento de performance": ["Aplicacao Mobile", "tarefa", "baixa"],
    "Testes de performance no Firestick": ["Aplicacao Mobile", "tarefa", "alta"],
    "Player com media_kit (4K HDR)": ["Aplicacao Mobile", "feature", "alta"],
    "Selecao de faixa de audio": ["Aplicacao Mobile", "feature", "alta"],
    "Selecao de legendas": ["Aplicacao Mobile", "feature", "alta"],
    "Ajuste de tela (5 modos)": ["Aplicacao Mobile", "feature", "alta"],
    "Historico de assistidos": ["Aplicacao Mobile", "feature", "media"],
    "Continuar assistindo": ["Aplicacao Mobile", "feature", "media"],
    "Filtros de qualidade": ["Aplicacao Mobile", "feature", "media"],
    "Cache persistente de playlist": ["Aplicacao Mobile", "melhoria", "media"],
    "Nova logo e icone": ["Aplicacao Mobile", "tarefa", "baixa"],
    "Renomeado para Click Channel": ["Aplicacao Mobile", "tarefa", "baixa"],
    "Firestick - Detectar device e otimizar": ["Aplicacao Mobile", "melhoria", "alta", "em andamento"],
}

print("Ajustando labels de todas as 60 issues...\n")

updated = 0
skipped = 0

for issue in repo.get_issues(state='all'):
    if issue.title in issue_labels_map:
        labels = issue_labels_map[issue.title]
        
        try:
            issue.set_labels(*labels)
            print(f"OK #{issue.number} - {labels}")
            updated += 1
        except Exception as e:
            print(f"ERRO #{issue.number}: {str(e)[:40]}")
    else:
        skipped += 1

print(f"\n{updated} issues atualizadas")
print(f"{skipped} issues nao encontradas no mapa")
print(f"\nLabels aplicadas com sucesso!")
