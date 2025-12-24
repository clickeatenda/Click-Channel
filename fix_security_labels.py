#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para corrigir labels das issues de segurança
"""

import os
import sys
from dotenv import load_dotenv
from github import Github, Auth

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "Click-Channel-Final"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

auth = Auth.Token(GITHUB_TOKEN)
g = Github(auth=auth)

try:
    repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)
    print(f"✅ Conectado ao repositório: {REPO_OWNER}/{REPO_NAME}\n")
except Exception as e:
    print(f"❌ Erro: {e}")
    exit(1)

print("=" * 70)
print("🔧 CORRIGINDO LABELS DAS ISSUES DE SEGURANÇA")
print("=" * 70)

# Mapear issues e suas labels corretas
issues_to_fix = {
    130: {  # Certificate Pinning
        "labels": ["Aplicação Mobile", "Funcionalidade", "🔴 Urgente", "🔧 Em Desenvolvimento"],
        "priority": "Urgente"
    },
    131: {  # Secure Storage
        "labels": ["Aplicação Mobile", "Melhoria", "🔴 Urgente", "🔧 Em Desenvolvimento"],
        "priority": "Urgente"
    },
    132: {  # Logs Sensíveis
        "labels": ["Aplicação Mobile", "Bug", "🟠 Alta", "🔧 Em Desenvolvimento"],
        "priority": "Alta"
    },
    133: {  # Validação de Input
        "labels": ["Aplicação Mobile", "Funcionalidade", "🟠 Alta", "🚀 Sprint Atual"],
        "priority": "Alta"
    },
    128: {  # .env histórico - já está correta mas vamos validar
        "labels": ["Infraestrutura", "Tarefa", "🔴 Urgente", "🚀 Sprint Atual"],
        "priority": "Urgente"
    },
    129: {  # Retry Strategy
        "labels": ["Backend / API", "Melhoria", "🟡 Média", "📋 Backlog e Planejamento"],
        "priority": "Média"
    }
}

print("\n📋 Listando labels disponíveis...")
available_labels = {}
for label in repo.get_labels():
    available_labels[label.name] = label
    
print(f"✅ {len(available_labels)} labels encontradas\n")

updated = 0
errors = 0

for issue_number, config in issues_to_fix.items():
    try:
        issue = repo.get_issue(issue_number)
        print(f"\n[Issue #{issue_number}] {issue.title[:60]}...")
        print(f"   Prioridade: {config['priority']}")
        
        current_labels = [l.name for l in issue.labels]
        print(f"   Labels atuais: {', '.join(current_labels) if current_labels else 'Nenhuma'}")
        
        # Verificar quais labels existem
        valid_labels = []
        missing_labels = []
        
        for label_name in config['labels']:
            if label_name in available_labels:
                valid_labels.append(label_name)
            else:
                missing_labels.append(label_name)
        
        if missing_labels:
            print(f"   ⚠️  Labels não encontradas: {', '.join(missing_labels)}")
        
        if valid_labels:
            # Atualizar labels
            issue.set_labels(*valid_labels)
            print(f"   ✅ Labels atualizadas: {', '.join(valid_labels)}")
            updated += 1
        else:
            print(f"   ❌ Nenhuma label válida para aplicar")
            errors += 1
            
    except Exception as e:
        print(f"   ❌ Erro ao atualizar issue #{issue_number}: {e}")
        errors += 1

print("\n" + "=" * 70)
print("📊 RESUMO")
print("=" * 70)
print(f"   ✅ Issues atualizadas: {updated}")
print(f"   ❌ Erros: {errors}")
print(f"   📝 Total processadas: {len(issues_to_fix)}")

if updated > 0:
    print("\n🎉 Labels corrigidas com sucesso!")
    print("🔗 Verifique: https://github.com/clickeatenda/Click-Channel-Final/issues")
    
print("\n" + "=" * 70)
print("\n📊 ISSUES POR PRIORIDADE:")
print("-" * 70)

urgentes = [k for k, v in issues_to_fix.items() if v['priority'] == 'Urgente']
altas = [k for k, v in issues_to_fix.items() if v['priority'] == 'Alta']
medias = [k for k, v in issues_to_fix.items() if v['priority'] == 'Média']

print(f"\n🔴 URGENTE ({len(urgentes)} issues):")
for num in urgentes:
    issue = repo.get_issue(num)
    print(f"   #{num} - {issue.title}")

print(f"\n🟠 ALTA ({len(altas)} issues):")
for num in altas:
    issue = repo.get_issue(num)
    print(f"   #{num} - {issue.title}")

print(f"\n🟡 MÉDIA ({len(medias)} issues):")
for num in medias:
    issue = repo.get_issue(num)
    print(f"   #{num} - {issue.title}")

print("\n✨ Script finalizado!")

