#!/usr/bin/env python3
"""
Script para criar issues do Firestick no GitHub
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

issues_to_create = [
    {
        "title": "🔥 Firestick: Trava na tela inicial ao carregar playlist",
        "body": """## Problema
Ao enviar playlist no Fire Stick, a aplicação carrega a lista mas trava na tela inicial (não responde ao controle, força fechamento).

## Contexto
- Tablet (192.168.3.159): funciona ok
- Fire Stick (192.168.3.110): trava
- Provável causa: memória limitada do Firestick

## Solução proposta
1. Limitar items iniciais carregados (50 em vez de 240)
2. Desabilitar shimmer/paginação virtual em devices com pouca memória
3. Aumentar timeouts para Firestick
4. Implementar detecção automática de dispositivo""",
        "labels": ["bug", "priority/alta", "section/performance", "device/firestick"]
    },
    {
        "title": "⚡ Otimizar carregamento inicial para dispositivos low-end",
        "body": """## Objetivo
Implementar otimizações específicas para Fire Stick e outros devices com pouca memória.

## Tarefas
- [ ] Detectar automaticamente se é Firestick/low-memory device
- [ ] Reduzir initial items de 240 para 50 em devices low-end
- [ ] Desabilitar shimmer loading em devices low-end
- [ ] Desabilitar paginação virtual inicial em devices low-end
- [ ] Aumentar timeouts de rede para Firestick
- [ ] Adicionar flag de debug para testar""",
        "labels": ["enhancement", "priority/alta", "section/performance", "device/firestick"]
    },
    {
        "title": "🧪 Adicionar testes de performance para Firestick",
        "body": """## Objetivo
Criar testes e benchmarks para garantir que o app funciona em devices low-end.

## Tarefas
- [ ] Criar teste de startup time no Firestick
- [ ] Verificar memory usage durante carregamento
- [ ] Teste de responsividade do controle
- [ ] Benchmark de lista grande (1000+ items)""",
        "labels": ["enhancement", "priority/média", "section/testing"]
    }
]

print(f"📝 Criando {len(issues_to_create)} issues no GitHub...\n")

for issue_data in issues_to_create:
    try:
        issue = repo.create_issue(
            title=issue_data["title"],
            body=issue_data["body"],
            labels=issue_data["labels"]
        )
        print(f"✅ Criada: #{issue.number} - {issue_data['title']}")
    except Exception as e:
        print(f"❌ Erro: {str(e)}")

print("\n🎉 Issues criadas!")
