#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para validar as issues de segurança criadas
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
print("🔍 VALIDANDO ISSUES DE SEGURANÇA CRIADAS")
print("=" * 70)

# Títulos esperados das issues de segurança
expected_titles = [
    "Implementar Certificate Pinning para Chamadas API",
    "Migrar Todas as Credenciais para Flutter Secure Storage",
    "Remover/Desabilitar Logs que Expõem Dados Sensíveis em Produção",
    "Verificar e Remover .env do Histórico do Git",
    "Implementar Retry Strategy Seguro para Requisições HTTP",
    "Adicionar Validação e Sanitização de Inputs do Usuário"
]

found_issues = []
missing_issues = []

print("\n📋 Buscando issues de segurança...\n")

# Buscar issues abertas recentemente
for issue in repo.get_issues(state='open', sort='created', direction='desc'):
    if issue.title in expected_titles:
        found_issues.append({
            'number': issue.number,
            'title': issue.title,
            'url': issue.html_url,
            'labels': [label.name for label in issue.labels],
            'milestone': issue.milestone.title if issue.milestone else 'N/A',
            'state': issue.state
        })

# Verificar quais issues foram criadas
for title in expected_titles:
    found = False
    for issue in found_issues:
        if issue['title'] == title:
            found = True
            break
    if not found:
        missing_issues.append(title)

print("=" * 70)
print(f"✅ ISSUES ENCONTRADAS: {len(found_issues)}/6")
print("=" * 70)

for idx, issue in enumerate(found_issues, 1):
    print(f"\n{idx}. Issue #{issue['number']}: {issue['title']}")
    print(f"   📍 URL: {issue['url']}")
    print(f"   🏷️  Labels: {', '.join(issue['labels']) if issue['labels'] else 'Nenhuma'}")
    print(f"   📌 Milestone: {issue['milestone']}")
    print(f"   🔄 Status: {issue['state'].upper()}")

if missing_issues:
    print("\n" + "=" * 70)
    print(f"⚠️  ISSUES NÃO ENCONTRADAS: {len(missing_issues)}/6")
    print("=" * 70)
    for title in missing_issues:
        print(f"   ❌ {title}")

print("\n" + "=" * 70)
print("📊 RESUMO FINAL")
print("=" * 70)
print(f"   ✅ Issues criadas: {len(found_issues)}")
print(f"   ❌ Issues faltando: {len(missing_issues)}")
print(f"   📝 Total esperado: 6")

if len(found_issues) == 6:
    print("\n   🎉 SUCESSO! Todas as 6 issues de segurança foram criadas!")
elif len(found_issues) > 0:
    print(f"\n   ⚠️  PARCIALMENTE COMPLETO: {len(found_issues)}/6 issues criadas")
else:
    print("\n   ❌ FALHA: Nenhuma issue encontrada")

print("\n🔗 Link do repositório:")
print(f"   https://github.com/{REPO_OWNER}/{REPO_NAME}/issues?q=is%3Aissue+is%3Aopen+sort%3Acreated-desc")

print("\n✨ Validação finalizada!")

