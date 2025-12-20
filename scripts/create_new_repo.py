#!/usr/bin/env python3
"""
Script para criar novo repositório ClickChannel e fazer mirror push
"""

import os
import subprocess
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
NEW_REPO_NAME = "ClickChannel"
OLD_REPO_NAME = "clickflix"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

print(f"🔄 Criando novo repositório {NEW_REPO_NAME}...\n")

g = Github(GITHUB_TOKEN)
auth_user = g.get_user()

try:
    # Criar novo repositório
    new_repo = auth_user.create_repo(
        name=NEW_REPO_NAME,
        description="Click Channel - App de Streaming IPTV",
        private=False,
        auto_init=False  # Não criar README automático
    )
    print(f"✅ Repositório criado: https://github.com/{REPO_OWNER}/{NEW_REPO_NAME}")
    
except Exception as e:
    if "already exists" in str(e):
        print(f"⚠️  Repositório {NEW_REPO_NAME} já existe. Continuando...")
        new_repo = auth_user.get_repo(NEW_REPO_NAME)
    else:
        print(f"❌ Erro ao criar repositório: {str(e)}")
        exit(1)

print(f"\n🔄 Fazendo mirror push do código...")

try:
    # Mirror push
    cmd = [
        "git",
        "push",
        "--mirror",
        f"https://github.com/{REPO_OWNER}/{NEW_REPO_NAME}.git"
    ]
    
    result = subprocess.run(cmd, cwd="d:\\ClickeAtenda-DEV\\Vs\\ClickFlix", capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"✅ Mirror push concluído com sucesso!")
        print(f"\n🎉 Novo repositório pronto em:")
        print(f"   https://github.com/{REPO_OWNER}/{NEW_REPO_NAME}")
    else:
        print(f"❌ Erro no mirror push:")
        print(result.stderr)
        exit(1)
        
except Exception as e:
    print(f"❌ Erro ao executar mirror push: {str(e)}")
    exit(1)

print("\n📝 Próximos passos:")
print(f"1. O novo repositório está em: https://github.com/{REPO_OWNER}/{NEW_REPO_NAME}")
print(f"2. Sem nenhuma issue (limpo!)")
print(f"3. Com todo o código e histórico de commits")
print(f"4. Clone com: git clone https://github.com/{REPO_OWNER}/{NEW_REPO_NAME}.git")
