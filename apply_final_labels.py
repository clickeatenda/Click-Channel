#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aplicar labels corretas em todas as 60 issues
"""

import os
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "Click-Channel-Final"

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

# Mapeamento completo de labels
labels_map = {
    "Player com media_kit (4K HDR)": ["Aplicacao Mobile", "feature", "alta"],
    "Selecao de faixa de audio": ["Aplicacao Mobile", "feature", "alta"],
    "Selecao de legendas": ["Aplicacao Mobile", "feature", "alta"],
    "Ajuste de tela (5 modos)": ["Aplicacao Mobile", "feature", "alta"],
    "Historico de assistidos": ["Aplicacao Mobile", "feature", "media"],
    "Continuar assistindo": ["Aplicacao Mobile", "feature", "media"],
    "Filtros de qualidade": ["Aplicacao Mobile", "feature", "media"],
    "Cache persistente de playlist": ["Aplicacao Mobile", "melhoria", "media"],
    "Parser de EPG (XMLTV format)": ["Aplicacao Mobile", "feature", "alta"],
    "Tela de programacao por canal": ["Aplicacao Mobile", "feature", "alta"],
    "Indicador Ao Vivo / Em breve": ["Aplicacao Mobile", "feature", "alta"],
    "Sistema de favoritos de programas": ["Aplicacao Mobile", "feature", "media"],
    "Configuracao de URL EPG": ["Aplicacao Mobile", "feature", "alta"],
    "Cache de EPG em disco": ["Aplicacao Mobile", "melhoria", "media"],
    "EPG mostrado somente em CANAIS": ["Aplicacao Mobile", "tarefa", "media"],
    "Notificacao de programa favorito": ["Aplicacao Mobile", "feature", "media"],
    "Lazy loading de imagens nos cards": ["Aplicacao Mobile", "melhoria", "media"],
    "Shimmer skeleton loading nos carrosseis": ["Aplicacao Mobile", "melhoria", "media"],
    "Cache de imagens com tamanho limitado": ["Aplicacao Mobile", "melhoria", "media"],
    "Compressao de thumbnails em memoria": ["Aplicacao Mobile", "melhoria", "media"],
    "Paginacao virtual em listas grandes": ["Aplicacao Mobile", "melhoria", "media"],
    "Remover .env do historico do git": ["Documentacao", "tarefa", "alta"],
    "Adicionar .env ao .gitignore": ["Documentacao", "tarefa", "alta"],
    "Migrar credenciais para flutter_secure_storage": ["Aplicacao Mobile", "feature", "alta"],
    "Implementar certificate pinning": ["Aplicacao Mobile", "feature", "alta"],
    "Filtro por ano de lancamento": ["Aplicacao Mobile", "feature", "media"],
    "Filtro por genero": ["Aplicacao Mobile", "feature", "media"],
    "Filtro por qualidade": ["Aplicacao Mobile", "feature", "media"],
    "Historico de buscas recentes": ["Aplicacao Mobile", "feature", "baixa"],
    "Sugestoes de busca (autocomplete)": ["Aplicacao Mobile", "feature", "baixa"],
    "Splash screen animada com logo": ["Aplicacao Mobile", "melhoria", "media"],
    "Indicador de carregamento elegante": ["Aplicacao Mobile", "melhoria", "media"],
    "Feedback sonoro na navegacao TV": ["Aplicacao Mobile", "melhoria", "baixa"],
    "Barra de progresso no card Continuar Assistindo": ["Aplicacao Mobile", "melhoria", "media"],
    "Animacoes de transicao entre telas": ["Aplicacao Mobile", "melhoria", "baixa"],
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
    "Monitoramento de performance": ["Aplicacao Mobile", "melhoria", "baixa"],
    "Testes de performance no Firestick": ["Aplicacao Mobile", "tarefa", "alta"],
    "Nova logo e icone": ["Aplicacao Mobile", "tarefa", "baixa"],
    "Renomeado para Click Channel": ["Aplicacao Mobile", "tarefa", "baixa"],
    "Firestick - Detectar device e otimizar": ["Aplicacao Mobile", "melhoria", "alta", "em andamento"],
}

print("Aplicando labels nas 60 issues...\n")

count = 0
for issue in repo.get_issues(state='all'):
    if issue.title in labels_map:
        try:
            issue.set_labels(*labels_map[issue.title])
            print(f"OK #{issue.number} - {', '.join(labels_map[issue.title])}")
            count += 1
        except Exception as e:
            print(f"ERRO #{issue.number}: {str(e)[:40]}")

print(f"\nTotal: {count} issues com labels aplicadas")
