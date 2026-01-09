#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para criar issues de segurança no Click-Channel-Final
"""

import os
import sys
from dotenv import load_dotenv
from github import Github

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "Click-Channel-Final"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado no arquivo .env")
    print("💡 Configure o token em .env: GITHUB_TOKEN=seu_token_aqui")
    exit(1)

g = Github(GITHUB_TOKEN)

try:
    repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)
    print(f"✅ Conectado ao repositório: {REPO_OWNER}/{REPO_NAME}\n")
except Exception as e:
    print(f"❌ Erro ao conectar ao repositório: {e}")
    exit(1)

# Definir as issues de segurança
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

**Labels:**
- Aplicação Mobile
- Funcionalidade
- Urgente
- Em Andamento

**Milestone - Status:** 🔧 Em Desenvolvimento
**Milestone - Fase:** Fase 2: Funcionalidades Principais
**Repositório:** Click-Channel-Final
**Responsável:** [Security Engineer / Senior Developer]
""",
        "labels": ["Aplicacao Mobile", "funcionalidade", "urgente", "em-andamento"],
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

**Labels:**
- Aplicação Mobile
- Melhoria
- Urgente
- Em Andamento

**Milestone - Status:** 🔧 Em Desenvolvimento
**Milestone - Fase:** Fase 2: Funcionalidades Principais
**Repositório:** Click-Channel-Final
**Responsável:** [Security Engineer / Senior Developer]
""",
        "labels": ["Aplicacao Mobile", "melhoria", "urgente", "em-andamento"],
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

**Labels:**
- Aplicação Mobile
- Bug
- Alta
- Em Andamento

**Milestone - Status:** 🔧 Em Desenvolvimento
**Milestone - Fase:** Fase 4: Performance e Otimização
**Repositório:** Click-Channel-Final
**Responsável:** [Developer]
""",
        "labels": ["Aplicacao Mobile", "bug", "alta", "em-andamento"],
        "milestone": "Fase 4: Performance e Otimização"
    },
    {
        "title": "Verificar e Remover .env do Histórico do Git",
        "body": """**Contexto:**
O ROADMAP.md indica que a tarefa "Remover .env do histórico do git" está marcada como "done", mas é necessário validar se foi realmente executada corretamente. O arquivo .env pode conter credenciais sensíveis.

**O que precisa ser feito:**
1. Executar git log --all --full-history -- ".env" para verificar histórico
2. Se .env estiver no histórico, usar BFG Repo-Cleaner ou git filter-branch
3. Verificar se .env está no .gitignore (já está - linha 22)
4. Fazer force push após limpeza (coordenar com equipe)
5. Documentar processo para evitar reincidência
6. Rotacionar todas as credenciais que estavam no .env comprometido

**Critérios de aceitação:**
- ✅ Arquivo .env completamente removido do histórico git
- ✅ .env no .gitignore (já está)
- ✅ Credenciais antigas rotacionadas
- ✅ Documentação do processo
- ✅ Guia para desenvolvedores sobre .env

**Impacto / Benefício:**
- Remove credenciais expostas do histórico público
- Compliance com práticas de segurança
- Evita vazamento de dados

**Arquivos afetados:**
- .env (remover do histórico)
- .gitignore (já configurado)
- Documentação (adicionar guia)

**Labels:**
- Infraestrutura
- Tarefa
- Urgente

**Milestone - Status:** 🚀 Sprint Atual
**Milestone - Fase:** Fase 1: Sistema de Design e Componentes
**Repositório:** Click-Channel-Final
**Responsável:** [DevOps / Tech Lead]
""",
        "labels": ["Infraestrutura", "tarefa", "urgente"],
        "milestone": "Fase 1: Sistema de Design e Componentes"
    },
    {
        "title": "Implementar Retry Strategy Seguro para Requisições HTTP",
        "body": """**Contexto:**
Atualmente, os timeouts estão configurados para 5 segundos (connectTimeout e receiveTimeout), o que pode ser curto para conexões lentas. Além disso, não há retry automático, o que impacta a experiência do usuário.

**O que precisa ser feito:**
1. Aumentar timeouts para valores mais realistas (10-15s)
2. Implementar retry automático com exponential backoff
3. Adicionar circuit breaker pattern para evitar retry infinito
4. Garantir que tokens não sejam re-enviados em retries desnecessários
5. Implementar cache de respostas quando apropriado
6. Adicionar rate limiting no lado do cliente

**Critérios de aceitação:**
- ✅ Timeouts ajustados (10-15s)
- ✅ Retry automático com max 3 tentativas
- ✅ Exponential backoff implementado
- ✅ Circuit breaker funcionando
- ✅ Tokens não expostos em logs de retry
- ✅ Testes de resiliência

**Impacto / Benefício:**
- Melhor experiência em conexões lentas
- Resiliência a falhas temporárias de rede
- Redução de chamadas desnecessárias

**Arquivos afetados:**
- lib/core/api/api_client.dart
- pubspec.yaml (adicionar dio_retry)

**Labels:**
- Backend / API
- Melhoria
- Média

**Milestone - Status:** 📋 Backlog e Planejamento
**Milestone - Fase:** Fase 4: Performance e Otimização
**Repositório:** Click-Channel-Final
**Responsável:** [A definir]
""",
        "labels": ["Backend / API", "melhoria", "media"],
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

**Labels:**
- Aplicação Mobile
- Funcionalidade
- Alta

**Milestone - Status:** 🚀 Sprint Atual
**Milestone - Fase:** Fase 2: Funcionalidades Principais
**Repositório:** Click-Channel-Final
**Responsável:** [Developer]
""",
        "labels": ["Aplicacao Mobile", "funcionalidade", "alta"],
        "milestone": "Fase 2: Funcionalidades Principais"
    }
]

print("🔒 Criando Issues de Segurança no GitHub...\n")
print("=" * 60)

created = 0
skipped = 0
errors = 0

# Verificar milestones existentes
print("\n📋 Verificando milestones existentes...")
existing_milestones = {}
try:
    for milestone in repo.get_milestones(state='all'):
        existing_milestones[milestone.title] = milestone
        print(f"   ✓ {milestone.title}")
except Exception as e:
    print(f"⚠️  Aviso: Não foi possível listar milestones: {e}")

print(f"\n📊 Total de milestones encontrados: {len(existing_milestones)}\n")
print("=" * 60)

# Criar issues
for idx, issue_data in enumerate(security_issues, 1):
    print(f"\n[{idx}/{len(security_issues)}] Criando: {issue_data['title'][:60]}...")
    
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
            # Criar a issue
            new_issue = repo.create_issue(
                title=issue_data['title'],
                body=issue_data['body'],
                labels=issue_data['labels']
            )
            
            # Tentar associar milestone se existir
            milestone_title = issue_data.get('milestone')
            if milestone_title and milestone_title in existing_milestones:
                try:
                    new_issue.edit(milestone=existing_milestones[milestone_title])
                    print(f"   ✅ CRIADA: Issue #{new_issue.number} (com milestone)")
                except Exception as e:
                    print(f"   ✅ CRIADA: Issue #{new_issue.number} (sem milestone: {e})")
            else:
                print(f"   ✅ CRIADA: Issue #{new_issue.number}")
                if milestone_title:
                    print(f"   ⚠️  Milestone '{milestone_title}' não encontrado")
            
            created += 1
            
    except Exception as e:
        print(f"   ❌ ERRO: {str(e)}")
        errors += 1

print("\n" + "=" * 60)
print(f"\n📊 RESUMO DA EXECUÇÃO:")
print(f"   ✅ Criadas:  {created}")
print(f"   ⏭️  Puladas:  {skipped}")
print(f"   ❌ Erros:    {errors}")
print(f"   📝 Total:    {len(security_issues)}")

if created > 0:
    print(f"\n🎉 Sucesso! {created} issues de segurança criadas.")
    print(f"🔗 Acesse: https://github.com/{REPO_OWNER}/{REPO_NAME}/issues")
else:
    print(f"\n⚠️  Nenhuma issue nova foi criada.")

if errors > 0:
    print(f"\n⚠️  Atenção: {errors} erro(s) ocorreram durante a criação.")

print("\n" + "=" * 60)
print("\n✨ Script finalizado!")

