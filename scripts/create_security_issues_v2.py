#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para criar issues de segurança no Click-Channel-Final (v2 - corrigido)
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
    print("❌ GITHUB_TOKEN não configurado no arquivo .env")
    exit(1)

# Usar Auth.Token (novo formato)
auth = Auth.Token(GITHUB_TOKEN)
g = Github(auth=auth)

try:
    repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)
    print(f"✅ Conectado ao repositório: {REPO_OWNER}/{REPO_NAME}\n")
except Exception as e:
    print(f"❌ Erro ao conectar ao repositório: {e}")
    exit(1)

# Listar labels existentes
print("🏷️  Listando labels existentes no repositório...")
existing_labels = {}
try:
    for label in repo.get_labels():
        existing_labels[label.name.lower()] = label.name
        print(f"   - {label.name}")
except Exception as e:
    print(f"⚠️  Erro ao listar labels: {e}")

print(f"\n📊 Total de labels: {len(existing_labels)}\n")
print("=" * 60)

# Função para encontrar label existente
def find_label(label_name):
    """Encontra label existente, case-insensitive"""
    normalized = label_name.lower()
    if normalized in existing_labels:
        return existing_labels[normalized]
    # Tentar variações
    variations = [
        label_name.replace(" ", "-"),
        label_name.replace(" ", "_"),
        label_name.replace("-", " "),
        label_name.replace("_", " ")
    ]
    for variation in variations:
        if variation.lower() in existing_labels:
            return existing_labels[variation.lower()]
    return None

# Definir as issues de segurança (apenas as que falharam + novas)
security_issues = [
    {
        "title": "Implementar Certificate Pinning para Chamadas API",
        "body": """**Contexto:**
Atualmente, as chamadas HTTP na aplicação não possuem certificate pinning, o que deixa vulnerável a ataques man-in-the-middle (MITM).

**O que precisa ser feito:**
1. Implementar certificate pinning no ApiClient (lib/core/api/api_client.dart)
2. Adicionar certificados SSL do backend no projeto
3. Configurar dio_certificate_pinning ou alternativa
4. Testar em ambiente de desenvolvimento e produção
5. Documentar processo de atualização de certificados

**Critérios de aceitação:**
- ✅ Certificate pinning implementado em todas as chamadas HTTP
- ✅ Testes de validação passando
- ✅ Proteção contra MITM attacks
- ✅ Tratamento adequado de erros de certificado
- ✅ Documentação atualizada

**Impacto / Benefício:**
- Aumenta significativamente a segurança das comunicações
- Protege dados sensíveis de interceptação
- Compliance com práticas de segurança mobile

**Arquivos afetados:**
- lib/core/api/api_client.dart
- pubspec.yaml (adicionar dio_certificate_pinning)
- assets/certificates/ (novos arquivos)

**Milestone - Status:** 🔧 Em Desenvolvimento
**Milestone - Fase:** Fase 2: Funcionalidades Principais
""",
        "labels_wanted": ["security", "enhancement", "high priority"],
        "milestone": "Fase 2: Funcionalidades Principais"
    },
    {
        "title": "Migrar Todas as Credenciais para Flutter Secure Storage",
        "body": """**Contexto:**
Atualmente, algumas credenciais e tokens podem estar sendo salvos em SharedPreferences ou em memória de forma insegura. É necessário migrar tudo para flutter_secure_storage.

**O que precisa ser feito:**
1. Auditar todos os locais onde credenciais são armazenadas
2. Migrar para flutter_secure_storage:
   - Tokens de autenticação (já implementado parcialmente)
   - URLs de playlist M3U (se contiverem credenciais)
   - Chaves de API
   - Qualquer dado sensível do usuário
3. Remover armazenamento inseguro de lib/core/prefs.dart
4. Implementar migração automática de dados existentes
5. Adicionar criptografia adicional se necessário

**Critérios de aceitação:**
- ✅ Todas as credenciais usando flutter_secure_storage
- ✅ Nenhum dado sensível em SharedPreferences
- ✅ Migração automática de dados existentes
- ✅ Testes unitários para validação
- ✅ Documentação de arquitetura atualizada

**Impacto / Benefício:**
- Credenciais protegidas por criptografia nativa (KeyStore/Keychain)
- Conformidade com LGPD/GDPR
- Proteção contra acesso não autorizado

**Arquivos afetados:**
- lib/core/prefs.dart
- lib/providers/auth_provider.dart
- lib/data/m3u_service.dart (se aplicável)

**Milestone - Status:** 🔧 Em Desenvolvimento
**Milestone - Fase:** Fase 2: Funcionalidades Principais
""",
        "labels_wanted": ["security", "enhancement", "high priority"],
        "milestone": "Fase 2: Funcionalidades Principais"
    },
    {
        "title": "Remover/Desabilitar Logs que Expõem Dados Sensíveis em Produção",
        "body": """**Contexto:**
O código atual possui LogInterceptor do Dio com requestBody: true e responseBody: true, além de múltiplos print() que podem expor dados sensíveis em logs de produção.

**O que precisa ser feito:**
1. Criar sistema de logging estruturado com níveis (DEBUG, INFO, ERROR)
2. Desabilitar logs sensíveis em modo release/produção
3. Remover LogInterceptor de requestBody/responseBody em produção
4. Revisar todos os print() e substituir por logger apropriado
5. Implementar log sanitization para remover tokens/senhas
6. Configurar logging apenas para ambiente de desenvolvimento

**Critérios de aceitação:**
- ✅ Nenhum dado sensível em logs de produção
- ✅ Sistema de logging estruturado implementado
- ✅ Configuração condicional por ambiente (dev/prod)
- ✅ Log sanitization funcionando
- ✅ Documentação de práticas de logging

**Impacto / Benefício:**
- Previne vazamento de dados sensíveis
- Compliance com práticas de segurança
- Logs mais limpos e úteis

**Arquivos afetados:**
- lib/core/api/api_client.dart (LogInterceptor)
- Todos os arquivos com print() (50+ ocorrências)
- Criar: lib/core/utils/logger.dart

**Milestone - Status:** 🔧 Em Desenvolvimento
**Milestone - Fase:** Fase 4: Performance e Otimização
""",
        "labels_wanted": ["security", "bug", "high priority"],
        "milestone": "Fase 4: Performance e Otimização"
    },
    {
        "title": "Adicionar Validação e Sanitização de Inputs do Usuário",
        "body": """**Contexto:**
Inputs do usuário (como URL de playlist M3U, EPG URL) não possuem validação robusta, o que pode permitir injection attacks ou comportamento inesperado.

**O que precisa ser feito:**
1. Implementar validação de URL (M3U_PLAYLIST_URL, EPG_URL)
2. Adicionar whitelist de protocolos permitidos (http, https, file)
3. Sanitizar inputs antes de usar em queries ou armazenamento
4. Validar formato de email/senha no login
5. Implementar rate limiting em formulários
6. Adicionar validação de tamanho de arquivo para uploads

**Critérios de aceitação:**
- ✅ Validação de URL implementada
- ✅ Whitelist de protocolos funcionando
- ✅ Sanitização de inputs
- ✅ Mensagens de erro claras para usuário
- ✅ Testes unitários de validação
- ✅ Documentação de regras de validação

**Impacto / Benefício:**
- Proteção contra injection attacks
- Melhor experiência do usuário com validações claras
- Previne comportamento inesperado

**Arquivos afetados:**
- lib/screens/settings_screen.dart
- lib/screens/login_screen.dart
- lib/data/m3u_service.dart
- Criar: lib/core/utils/validators.dart

**Milestone - Status:** 🚀 Sprint Atual
**Milestone - Fase:** Fase 2: Funcionalidades Principais
""",
        "labels_wanted": ["security", "enhancement", "high priority"],
        "milestone": "Fase 2: Funcionalidades Principais"
    }
]

# Verificar milestones existentes
print("\n📋 Verificando milestones existentes...")
existing_milestones = {}
try:
    for milestone in repo.get_milestones(state='all'):
        existing_milestones[milestone.title] = milestone
except Exception as e:
    print(f"⚠️  Erro ao listar milestones: {e}")

print("\n" + "=" * 60)
print("🔒 Criando Issues de Segurança (que falharam anteriormente)...\n")

created = 0
skipped = 0
errors = 0

for idx, issue_data in enumerate(security_issues, 1):
    print(f"[{idx}/{len(security_issues)}] Criando: {issue_data['title'][:60]}...")
    
    try:
        # Verificar se já existe
        existing = False
        for existing_issue in repo.get_issues(state='all'):
            if existing_issue.title == issue_data['title']:
                print(f"   ⏭️  JÁ EXISTE: Issue #{existing_issue.number}")
                skipped += 1
                existing = True
                break
        
        if not existing:
            # Encontrar labels válidas
            valid_labels = []
            for wanted_label in issue_data['labels_wanted']:
                found = find_label(wanted_label)
                if found:
                    valid_labels.append(found)
                else:
                    print(f"   ⚠️  Label '{wanted_label}' não encontrada, ignorando...")
            
            if not valid_labels:
                print(f"   ⚠️  Nenhuma label válida encontrada, criando sem labels...")
            
            # Criar a issue
            new_issue = repo.create_issue(
                title=issue_data['title'],
                body=issue_data['body'],
                labels=valid_labels if valid_labels else []
            )
            
            # Tentar associar milestone
            milestone_title = issue_data.get('milestone')
            if milestone_title and milestone_title in existing_milestones:
                try:
                    new_issue.edit(milestone=existing_milestones[milestone_title])
                    print(f"   ✅ CRIADA: Issue #{new_issue.number} (com milestone e {len(valid_labels)} labels)")
                except Exception as e:
                    print(f"   ✅ CRIADA: Issue #{new_issue.number} (sem milestone: {e})")
            else:
                print(f"   ✅ CRIADA: Issue #{new_issue.number} ({len(valid_labels)} labels)")
            
            created += 1
            
    except Exception as e:
        print(f"   ❌ ERRO: {str(e)}")
        errors += 1

print("\n" + "=" * 60)
print(f"\n📊 RESUMO:")
print(f"   ✅ Criadas:  {created}")
print(f"   ⏭️  Puladas:  {skipped}")
print(f"   ❌ Erros:    {errors}")
print(f"   📝 Total:    {len(security_issues)}")

if created > 0:
    print(f"\n🎉 Sucesso! {created} issues de segurança criadas.")
    print(f"🔗 Acesse: https://github.com/{REPO_OWNER}/{REPO_NAME}/issues")

print("\n✨ Script finalizado!")

