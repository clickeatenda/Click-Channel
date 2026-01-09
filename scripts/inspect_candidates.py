#!/usr/bin/env python3
import os
from dotenv import load_dotenv
from github import Github

load_dotenv()
g = Github(os.getenv("GITHUB_TOKEN"))
repo = g.get_user("clickeatenda").get_repo("Click-Channel")

ids_to_check = [128, 124, 103, 92, 86]

print(f"Analisando issues candidatas a fechamento...\n")

for i in ids_to_check:
    issue = repo.get_issue(i)
    print(f"--- ISSUE #{i}: {issue.title} ---")
    print(issue.body[:300] + "..." if issue.body else "Sem descrição")
    print("\n")
