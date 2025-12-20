#!/usr/bin/env python3
"""
Script para deletar TODAS as issues do repositório
"""

import os
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "clickflix"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

print(f"⚠️  DELETANDO TODAS AS ISSUES de {REPO_OWNER}/{REPO_NAME}...\n")

# Pegar todas as issues (abertas e fechadas)
all_issues = list(repo.get_issues(state='all'))

if not all_issues:
    print("✅ Nenhuma issue encontrada. Repositório limpo!")
    exit(0)

print(f"📋 Total de issues encontradas: {len(all_issues)}\n")

deleted = 0
failed = 0

for issue in all_issues:
    try:
        print(f"🗑️  Deletando #{issue.number} - {issue.title}")
        issue.edit(state='closed')  # Fechar antes de deletar
        # GitHub não tem API para deletar issues diretamente
        # Vamos apenas fechar todas
        deleted += 1
    except Exception as e:
        print(f"❌ Erro ao processar #{issue.number}: {str(e)}")
        failed += 1

print(f"\n✨ Resumo: {deleted} issues fechadas, {failed} erros")
print("\n⚠️  Nota: GitHub não permite deletar issues via API.")
print("   Todas as issues foram FECHADAS em vez de deletadas.")
print("   Para deletar permanentemente, acesse: https://github.com/clickeatenda/clickflix/issues")
