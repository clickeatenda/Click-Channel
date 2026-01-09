#!/usr/bin/env python3
import os
from dotenv import load_dotenv
from github import Github

load_dotenv()
g = Github(os.getenv("GITHUB_TOKEN"))
repo = g.get_user("clickeatenda").get_repo("Click-Channel")

issues_to_close = [
    {"id": 92, "comment": "✅ Suporte a legendas externas implementado via integração Jellyfin."},
    {"id": 86, "comment": "✅ Barra de progresso implementada nos cards de conteúdo (Continue Watching)."}
]

print("Fechando issues resolvidas...\n")

for item in issues_to_close:
    try:
        issue = repo.get_issue(item["id"])
        print(f"Fechando #{item['id']}: {issue.title}")
        issue.create_comment(item["comment"])
        issue.edit(state="closed", labels=["status/done"])
        print("-> Sucesso!")
    except Exception as e:
        print(f"-> Erro: {e}")

print("\nConcluído.")
