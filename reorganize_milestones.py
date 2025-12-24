#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Reajustar 120 issues (60 abertas + 60 fechadas) com novo padrão de Milestones
Click-Channel-Final é MOBILE, então usa:
- Fase 1: Sistema de Design e Componentes
- Fase 2: Funcionalidades Principais
- Fase 3: Polimento da Interface
- Fase 4: Performance e Otimização
- Fase 5: Implantação e Monitoramento

Status de Milestone:
- 📋 Backlog e Planejamento (TODO)
- 🚀 Sprint Atual (TODO prioritário)
- 🔧 Em Desenvolvimento (IN-PROGRESS)
- 🧪 Testes e Garantia de Qualidade (em testes)
- ✅ Pronto para Implantação (pronto para deploy)
- 🚢 Produção (já em produção)
- 📊 Monitoramento e Feedback (monitorando)
- ⏸️ Arquivado (cancelado/obsoleto)
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

# Mapear issues para milestones corretos
milestone_map = {
    # DONE - Histórico (22 issues)
    "Remover .env do historico do git": ("✅ Pronto para Implantação", "Fase 1: Sistema de Design e Componentes"),
    "Adicionar .env ao .gitignore": ("✅ Pronto para Implantação", "Fase 1: Sistema de Design e Componentes"),
    "Parser de EPG (XMLTV format)": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Tela de programacao por canal": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Indicador Ao Vivo / Em breve": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Sistema de favoritos de programas": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Configuracao de URL EPG": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Cache de EPG em disco": ("🚢 Produção", "Fase 4: Performance e Otimização"),
    "EPG mostrado somente em CANAIS": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Lazy loading de imagens nos cards": ("🚢 Produção", "Fase 4: Performance e Otimização"),
    "Shimmer skeleton loading nos carrosseis": ("🚢 Produção", "Fase 4: Performance e Otimização"),
    "Cache de imagens com tamanho limitado": ("🚢 Produção", "Fase 4: Performance e Otimização"),
    "Compressao de thumbnails em memoria": ("🚢 Produção", "Fase 4: Performance e Otimização"),
    "Paginacao virtual em listas grandes": ("🚢 Produção", "Fase 4: Performance e Otimização"),
    "Reset playlist & cache": ("🚢 Produção", "Fase 3: Polimento da Interface"),
    "Agrupamento de variantes por canal": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Player com media_kit (4K HDR)": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Selecao de faixa de audio": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Selecao de legendas": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Ajuste de tela (5 modos)": ("🚢 Produção", "Fase 2: Funcionalidades Principais"),
    "Nova logo e icone": ("🚢 Produção", "Fase 1: Sistema de Design e Componentes"),
    "Renomeado para Click Channel": ("🚢 Produção", "Fase 1: Sistema de Design e Componentes"),
    
    # IN-PROGRESS (2 issues)
    "Testes unitarios (coverage > 70%)": ("🔧 Em Desenvolvimento", "Fase 5: Implantação e Monitoramento"),
    "Firestick - Detectar device e otimizar": ("🔧 Em Desenvolvimento", "Fase 4: Performance e Otimização"),
    
    # TODO - Sprint Atual (10 issues prioritárias)
    "Historico de assistidos": ("🚀 Sprint Atual", "Fase 2: Funcionalidades Principais"),
    "Continuar assistindo": ("🚀 Sprint Atual", "Fase 2: Funcionalidades Principais"),
    "Filtros de qualidade": ("🚀 Sprint Atual", "Fase 2: Funcionalidades Principais"),
    "Cache persistente de playlist": ("🚀 Sprint Atual", "Fase 4: Performance e Otimização"),
    "Notificacao de programa favorito": ("🚀 Sprint Atual", "Fase 2: Funcionalidades Principais"),
    "Migrar credenciais para flutter_secure_storage": ("🚀 Sprint Atual", "Fase 1: Sistema de Design e Componentes"),
    "Implementar certificate pinning": ("🚀 Sprint Atual", "Fase 1: Sistema de Design e Componentes"),
    "Splash screen animada com logo": ("🚀 Sprint Atual", "Fase 3: Polimento da Interface"),
    "Indicador de carregamento elegante": ("🚀 Sprint Atual", "Fase 3: Polimento da Interface"),
    "Barra de progresso no card Continuar Assistindo": ("🚀 Sprint Atual", "Fase 3: Polimento da Interface"),
    
    # TODO - Backlog (48 issues)
    "Filtro por ano de lancamento": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Filtro por genero": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Filtro por qualidade": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Historico de buscas recentes": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Sugestoes de busca (autocomplete)": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Feedback sonoro na navegacao TV": ("📋 Backlog e Planejamento", "Fase 3: Polimento da Interface"),
    "Animacoes de transicao entre telas": ("📋 Backlog e Planejamento", "Fase 3: Polimento da Interface"),
    "Modo picture in picture (PiP)": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Download para assistir offline": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Multiplos perfis de usuario": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Controle parental com PIN": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Legendas externas (.srt .ass .vtt)": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Sincronizacao de favoritos na nuvem": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Cast para Chromecast AirPlay": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Integracao com Leanback launcher": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Suporte a comandos de voz": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Recomendacoes na home do Android TV": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Channel Shortcuts": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Watch Next integration": ("📋 Backlog e Planejamento", "Fase 2: Funcionalidades Principais"),
    "Testes de widget": ("📋 Backlog e Planejamento", "Fase 5: Implantação e Monitoramento"),
    "Retry automatico em falhas de rede": ("📋 Backlog e Planejamento", "Fase 4: Performance e Otimização"),
    "Reconexao automatica do player": ("📋 Backlog e Planejamento", "Fase 4: Performance e Otimização"),
    "Firebase Crashlytics integration": ("📋 Backlog e Planejamento", "Fase 5: Implantação e Monitoramento"),
    "Analytics (Firebase Mixpanel)": ("📋 Backlog e Planejamento", "Fase 5: Implantação e Monitoramento"),
    "Monitoramento de performance": ("📋 Backlog e Planejamento", "Fase 4: Performance e Otimização"),
    "Testes de performance no Firestick": ("📋 Backlog e Planejamento", "Fase 4: Performance e Otimização"),
}

print("Reajustando milestones nas 120 issues...\n")

# Obter ou criar milestones
existing_milestones = {}
for ms in repo.get_milestones(state='all'):
    existing_milestones[ms.title] = ms

# Criar milestones que não existem
status_milestones = [
    "📋 Backlog e Planejamento",
    "🚀 Sprint Atual",
    "🔧 Em Desenvolvimento",
    "🧪 Testes e Garantia de Qualidade",
    "✅ Pronto para Implantação",
    "🚢 Produção",
    "📊 Monitoramento e Feedback",
    "⏸️ Arquivado"
]

phase_milestones = [
    "Fase 1: Sistema de Design e Componentes",
    "Fase 2: Funcionalidades Principais",
    "Fase 3: Polimento da Interface",
    "Fase 4: Performance e Otimização",
    "Fase 5: Implantação e Monitoramento"
]

all_milestones = status_milestones + phase_milestones

for ms_title in all_milestones:
    if ms_title not in existing_milestones:
        try:
            ms = repo.create_milestone(title=ms_title)
            existing_milestones[ms_title] = ms
            print(f"Milestone criado: {ms_title}")
        except Exception as e:
            print(f"Erro ao criar milestone {ms_title}: {str(e)[:50]}")

print("\nAplicando milestones...\n")

# Aplicar milestones às issues
updated = 0
for issue in repo.get_issues(state='all'):
    if issue.title in milestone_map:
        status_ms, phase_ms = milestone_map[issue.title]
        
        # Para issues DONE, aplicar milestone de Produção/Pronto
        # Para issues IN-PROGRESS e TODO, aplicar conforme mapa
        try:
            # Aqui seria ideal aplicar 2 milestones, mas GitHub permite apenas 1 por issue
            # Vamos usar a Fase (Phase) como principal para rastreabilidade
            if phase_ms in existing_milestones:
                issue.edit(milestone=existing_milestones[phase_ms])
                print(f"OK #{issue.number} - {phase_ms}")
                updated += 1
        except Exception as e:
            print(f"ERRO #{issue.number}: {str(e)[:40]}")

print(f"\n✅ {updated} issues com milestones reajustadas")
print(f"\nNota: GitHub permite apenas 1 milestone por issue.")
print(f"Aplicamos as FASES como milestone principal para rastreabilidade.")
