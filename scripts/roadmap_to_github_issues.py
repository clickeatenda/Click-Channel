#!/usr/bin/env python3
"""
Script para converter ROADMAP.md em issues do GitHub.
Requisitos: pip install PyGithub python-dotenv
"""

import os
import re
import sys
from dotenv import load_dotenv
from github import Github

load_dotenv()

# GitHub token (usar variável de ambiente)
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "clickflix"
ROADMAP_FILE = "ROADMAP.md"

if not GITHUB_TOKEN:
    print("❌ ERRO: Variável GITHUB_TOKEN não definida. Configure em .env")
    sys.exit(1)

def parse_roadmap(file_path):
    """Parse ROADMAP.md e extrai items como issues"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    issues = []
    current_section = None
    current_priority = None
    
    lines = content.split('\n')
    
    for i, line in enumerate(lines):
        # Detectar prioridade (Alta, Média, Baixa)
        if '🔴 Prioridade Alta' in line:
            current_priority = 'Alta'
        elif '🟡 Prioridade Média' in line:
            current_priority = 'Média'
        elif '🟢 Prioridade Baixa' in line:
            current_priority = 'Baixa'
        
        # Detectar seções (###)
        if line.startswith('### '):
            current_section = line.replace('### ', '').strip()
        
        # Detectar items de roadmap (- [ ] ou - [x])
        if line.startswith('- [') and current_section:
            # Extract checkbox state and text
            match = re.match(r'- \[([ xX~!])\]\s*(.*)', line)
            if match:
                status = match.group(1)
                text = match.group(2).strip()
                
                # Mapear status
                if status == 'x':
                    issue_status = 'done'
                elif status == '~':
                    issue_status = 'in_progress'
                elif status == '!':
                    issue_status = 'blocked'
                else:
                    issue_status = 'todo'
                
                issues.append({
                    'title': text,
                    'section': current_section,
                    'priority': current_priority or 'Média',
                    'status': issue_status,
                    'body': f"**Seção:** {current_section}\n**Prioridade:** {current_priority or 'Média'}\n\n{text}"
                })
    
    return issues

def map_labels(section, priority, status):
    """Mapear labels para o GitHub"""
    labels = [f"priority/{priority.lower()}"]
    
    if status == 'done':
        labels.append('status/done')
    elif status == 'in_progress':
        labels.append('status/in-progress')
    elif status == 'blocked':
        labels.append('status/blocked')
    else:
        labels.append('status/todo')
    
    # Adicionar label de seção
    section_label = section.lower().replace(' ', '-')
    labels.append(f"section/{section_label}")
    
    return labels

def create_github_issues(issues):
    """Criar issues no GitHub"""
    g = Github(GITHUB_TOKEN)
    repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)
    
    print(f"📝 Criando {len(issues)} issues no repositório {REPO_OWNER}/{REPO_NAME}...\n")
    
    created = 0
    skipped = 0
    
    for issue_data in issues:
        try:
            labels = map_labels(issue_data['section'], issue_data['priority'], issue_data['status'])
            
            # Verificar se issue já existe (por título)
            existing = False
            for existing_issue in repo.get_issues(state='all'):
                if existing_issue.title == issue_data['title']:
                    print(f"⏭️  Pulando (já existe): {issue_data['title']}")
                    existing = True
                    skipped += 1
                    break
            
            if not existing:
                issue = repo.create_issue(
                    title=issue_data['title'],
                    body=issue_data['body'],
                    labels=labels
                )
                print(f"✅ Criada: #{issue.number} - {issue_data['title']}")
                created += 1
        
        except Exception as e:
            print(f"❌ Erro ao criar issue '{issue_data['title']}': {str(e)}")
    
    print(f"\n✨ Resumo: {created} criadas, {skipped} puladas")
    return created, skipped

if __name__ == '__main__':
    if not os.path.exists(ROADMAP_FILE):
        print(f"❌ Arquivo {ROADMAP_FILE} não encontrado")
        sys.exit(1)
    
    print(f"📖 Parseando {ROADMAP_FILE}...\n")
    issues = parse_roadmap(ROADMAP_FILE)
    print(f"✅ {len(issues)} items encontrados\n")
    
    create_github_issues(issues)
    print("\n🎉 Conversão concluída! Acesse: https://github.com/clickeatenda/clickflix/issues")
