#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script alternativo para ajustar labels com retry e timeout maior
"""

import os
import sys
import time
from dotenv import load_dotenv
from github import Github

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
if not GITHUB_TOKEN:
    print("GITHUB_TOKEN nao configurado")
    exit(1)

# Retry com delays
max_retries = 3
for attempt in range(max_retries):
    try:
        print(f"Tentativa {attempt + 1}/{max_retries}...\n")
        
        g = Github(GITHUB_TOKEN, timeout=30)
        repo = g.get_user("clickeatenda").get_repo("Click-Channel-Final")
        
        # Mapas simplificados
        labels_map = {
            "Aplicacao Mobile": "Aplicacao Mobile",
            "feature": "feature",
            "melhoria": "melhoria",
            "tarefa": "tarefa",
            "alta": "alta",
            "media": "media",
            "baixa": "baixa",
            "em andamento": "em andamento"
        }
        
        updated = 0
        for issue in repo.get_issues(state='all', per_page=30):
            # Limpar labels antigas
            try:
                for label in issue.labels:
                    issue.remove_from_labels(label)
            except:
                pass
            
            # Adicionar label base (Aplicacao Mobile)
            try:
                issue.add_to_labels("Aplicacao Mobile")
                
                # Adicionar status se necessario
                if "in-progress" in issue.title.lower() or "andamento" in issue.title.lower():
                    issue.add_to_labels("em andamento")
                elif "firestick" in issue.title.lower():
                    issue.add_to_labels("em andamento")
                    issue.add_to_labels("melhoria")
                    issue.add_to_labels("alta")
                elif "testes unitarios" in issue.title.lower():
                    issue.add_to_labels("em andamento")
                    issue.add_to_labels("tarefa")
                    issue.add_to_labels("media")
                else:
                    # Labels padrao
                    issue.add_to_labels("feature")
                    if any(word in issue.title.lower() for word in ["alta", "seguranca", "player", "cache", "epg"]):
                        issue.add_to_labels("alta")
                    elif any(word in issue.title.lower() for word in ["filtro", "historico", "continue"]):
                        issue.add_to_labels("media")
                    else:
                        issue.add_to_labels("baixa")
                
                print(f"OK #{issue.number}")
                updated += 1
            except Exception as e:
                print(f"SKIP #{issue.number}: {str(e)[:30]}")
        
        print(f"\n{updated} issues atualizadas!")
        break
        
    except Exception as e:
        error_msg = str(e)
        print(f"ERRO na tentativa {attempt + 1}: {error_msg[:60]}")
        
        if attempt < max_retries - 1:
            print(f"Aguardando 20 segundos antes de retry...\n")
            time.sleep(20)
        else:
            print("\nFalha apos todas as tentativas!")
            exit(1)
