#!/usr/bin/env python3
"""
Script para criar issues da integração Jellyfin no ClickChannel
Baseado no plano de implementação definido
"""

import os
from dotenv import load_dotenv
from github import Github

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "ClickChannel"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

g = Github(GITHUB_TOKEN)
repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)

# Issues para integração Jellyfin com SharkFlix
issues = [
    # ============ PLANEJAMENTO ============
    {
        "title": "[PLANNING] Definir arquitetura de integração Jellyfin API",
        "body": """## 📋 Planejamento: Arquitetura Jellyfin

### Objetivo:
Documentar a arquitetura completa de integração com a API do Jellyfin para a página SharkFlix.

### Tarefas:
- [ ] Revisar documentação oficial da API Jellyfin
- [ ] Definir endpoints necessários (autenticação, bibliotecas, items, streaming)
- [ ] Mapear fluxo de dados: Jellyfin → ContentItem
- [ ] Definir estratégia de cache e performance
- [ ] Documentar estrutura de erros e fallbacks

### Referências:
- Documentação: https://api.jellyfin.org/
- Plan: [implementation_plan.md](file:///C:/Users/joaov/.gemini/antigravity/brain/1999ae5a-ffe2-4266-9a0a-d886ba26d24f/implementation_plan.md)

### Prioridade: ALTA
### Estimativa: 2-3 horas
""",
        "labels": ["status/todo", "priority/alta", "section/planning", "feature/jellyfin"]
    },

    {
        "title": "[PLANNING] Definir estrutura de configuração Jellyfin",
        "body": """## 🔧 Planejamento: Configuração

### Objetivo:
Definir como armazenar e gerenciar credenciais e configurações do servidor Jellyfin.

### Tarefas:
- [ ] Adicionar variáveis ao `.env` (URL, username, password, library_id)
- [ ] Decidir sobre armazenamento seguro de tokens (flutter_secure_storage)
- [ ] Definir UI de configuração (Settings screen)
- [ ] Planejar validação de conexão
- [ ] Documentar setup inicial no README

### Segurança:
> [!IMPORTANT]
> Tokens de acesso devem usar `flutter_secure_storage`, não `SharedPreferences`.

### Prioridade: ALTA
### Estimativa: 1-2 horas
""",
        "labels": ["status/todo", "priority/alta", "section/planning", "feature/jellyfin", "section/security"]
    },

    {
        "title": "[PLANNING] Planejar mapeamento de dados Jellyfin → ContentItem",
        "body": """## 🗺️ Planejamento: Mapeamento de Dados

### Objetivo:
Definir como converter objetos da API Jellyfin para o modelo `ContentItem` já usado no app.

### Tarefas:
- [ ] Revisar modelo `ContentItem` atual
- [ ] Mapear campos Jellyfin → ContentItem:
  - `Name` → `title`
  - `ImageTags.Primary` → `image`
  - `Id` → URL de streaming
  - `Type` → `type` (movie/series/channel)
- [ ] Definir campos adicionais necessários (jellyfinId, overview, year)
- [ ] Planejar tratamento de campos opcionais
- [ ] Documentar conversão de URLs de imagem

### Prioridade: MÉDIA
### Estimativa: 1-2 horas
""",
        "labels": ["status/todo", "priority/média", "section/planning", "feature/jellyfin"]
    },

    # ============ IMPLEMENTAÇÃO ============
    {
        "title": "[IMPLEMENTATION] Criar JellyfinService",
        "body": """## 🔨 Implementação: Serviço Jellyfin

### Objetivo:
Criar `lib/data/jellyfin_service.dart` com toda a lógica de comunicação com a API Jellyfin.

### Métodos a implementar:
- [x] `initialize()` - Carregar configurações do .env
- [ ] `authenticate(username, password)` - Login e obtenção de token
- [ ] `getLibraries()` - Listar bibliotecas disponíveis
- [ ] `getItems({libraryId, searchTerm, type})` - Buscar itens
- [ ] `getLatestItems({count})` - Itens recém-adicionados
- [ ] `getFeaturedItems({count})` - Itens em destaque
- [ ] `getStreamUrl(itemId)` - Gerar URL de streaming
- [ ] `_mapJellyfinToContentItem(item)` - Conversão de modelo

### Recursos técnicos:
- Usar `http` ou `dio` para chamadas HTTP
- Implementar retry automático com `dio_smart_retry`
- Cache de tokens em `flutter_secure_storage`
- Tratamento de erros robusto

### Arquivo:
`lib/data/jellyfin_service.dart`

### Prioridade: ALTA
### Estimativa: 4-6 horas
""",
        "labels": ["status/in-progress", "priority/alta", "section/implementation", "feature/jellyfin"]
    },

    {
        "title": "[IMPLEMENTATION] Adicionar configurações Jellyfin no .env",
        "body": """## ⚙️ Implementação: Variáveis de Ambiente

### Objetivo:
Adicionar variáveis de configuração do Jellyfin no `.env` e `.env.example`.

### Variáveis a adicionar:
```env
# Jellyfin Server Configuration
JELLYFIN_URL=http://192.168.1.100:8096
JELLYFIN_USERNAME=usuario
JELLYFIN_PASSWORD=senha
JELLYFIN_LIBRARY_ID=  # ID da biblioteca específica (opcional)
```

### Tarefas:
- [ ] Atualizar `.env.example`
- [ ] Documentar variáveis no README
- [ ] Adicionar validação de variáveis obrigatórias
- [ ] Testar carregamento com flutter_dotenv

### Arquivos:
- `.env.example`
- `README.md`

### Prioridade: ALTA
### Estimativa: 30 minutos
""",
        "labels": ["status/todo", "priority/alta", "section/implementation", "feature/jellyfin"]
    },

    {
        "title": "[IMPLEMENTATION] Atualizar SharkFlix para consumir Jellyfin API",
        "body": """## 🦈 Implementação: Integração SharkFlix

### Objetivo:
Modificar a página SharkFlix (`_SharkflixBody`) para usar dados do Jellyfin em vez de M3U.

### Tarefas:
- [ ] Adicionar toggle para escolher fonte: M3U vs Jellyfin
- [ ] Criar método `_loadFromJellyfin()`
- [ ] Substituir chamadas `M3uService` por `JellyfinService`
- [ ] Manter compatibilidade com M3U (fallback)
- [ ] Adicionar indicador de status de conexão
- [ ] Tratamento de erros com feedback visual

### UI Additions:
- Status badge (conectado/desconectado)
- Toggle de fonte de dados
- Loading states

### Arquivo:
`lib/screens/home_screen.dart` (linhas 1820-1923)

### Prioridade: ALTA
### Estimativa: 3-4 horas
""",
        "labels": ["status/todo", "priority/alta", "section/implementation", "feature/jellyfin"]
    },

    {
        "title": "[IMPLEMENTATION] Implementar autenticação com Jellyfin",
        "body": """## 🔐 Implementação: Autenticação

### Objetivo:
Implementar fluxo completo de autenticação com servidor Jellyfin.

### Tarefas:
- [ ] Endpoint `/Users/AuthenticateByName`
- [ ] Gerar header `X-Emby-Authorization`
- [ ] Armazenar token em `flutter_secure_storage`
- [ ] Implementar refresh de token
- [ ] Validar credenciais na inicialização
- [ ] UI de login/configuração (se necessário)

### Segurança:
> [!WARNING]
> Nunca armazenar senha em plain text. Use apenas tokens após autenticação.

### Fluxo:
1. Usuário fornece username/password (via .env ou UI)
2. App chama `authenticate()`
3. Servidor retorna `AccessToken` e `UserId`
4. Token é armazenado de forma segura
5. Todas as chamadas subsequentes usam o token

### Prioridade: ALTA
### Estimativa: 2-3 horas
""",
        "labels": ["status/todo", "priority/alta", "section/implementation", "feature/jellyfin", "section/security"]
    },

    {
        "title": "[IMPLEMENTATION] Mapear bibliotecas e itens do Jellyfin",
        "body": """## 📚 Implementação: Mapeamento de Bibliotecas

### Objetivo:
Implementar descoberta e mapeamento de bibliotecas e itens do Jellyfin.

### Tarefas:
- [ ] Endpoint `/Library/MediaFolders` - Listar bibliotecas
- [ ] Endpoint `/Items` - Buscar itens de biblioteca
- [ ] Endpoint `/Users/{userId}/Items/Latest` - Itens recentes
- [ ] Filtrar por tipo (movies, tvshows)
- [ ] Conversão de metadados (overview, year, rating)
- [ ] Mapeamento de URLs de imagens

### Campos obrigatórios:
- `Id` - Identificador único
- `Name` - Título
- `Type` - Tipo de mídia
- `ImageTags.Primary` - Imagem principal

### Prioridade: MÉDIA
### Estimativa: 2-3 horas
""",
        "labels": ["status/todo", "priority/média", "section/implementation", "feature/jellyfin"]
    },

    # ============ TESTES ============
    {
        "title": "[TESTING] Verificar conexão com servidor Jellyfin",
        "body": """## ✅ Testes: Conectividade

### Objetivo:
Garantir que a aplicação consegue conectar ao servidor Jellyfin configurado.

### Cenários de teste:
- [ ] Servidor disponível e credenciais corretas → Sucesso
- [ ] Servidor indisponível → Erro tratado com mensagem clara
- [ ] Credenciais inválidas → Erro de autenticação
- [ ] URL inválida → Timeout tratado
- [ ] Sem configuração → Fallback gracioso

### Ferramentas:
- Logs de debug
- Indicador visual de status
- Toast messages para erros

### Acceptance Criteria:
- ✅ App não trava se Jellyfin estiver offline
- ✅ Mensagens de erro são claras e úteis
- ✅ Fallback para M3U funciona automaticamente

### Prioridade: ALTA
### Estimativa: 1-2 horas
""",
        "labels": ["status/todo", "priority/alta", "section/testing", "feature/jellyfin"]
    },

    {
        "title": "[TESTING] Testar carregamento de conteúdo do Jellyfin",
        "body": """## ✅ Testes: Carregamento de Conteúdo

### Objetivo:
Validar que itens do Jellyfin são carregados e exibidos corretamente na SharkFlix.

### Cenários de teste:
- [ ] Bibliotecas vazias → Mensagem apropriada
- [ ] Biblioteca com 1 item → Exibido corretamente
- [ ] Biblioteca com 100+ items → Paginação funciona
- [ ] Imagens carregam corretamente
- [ ] Metadados (título, ano, overview) corretos
- [ ] Featured carousel exibe itens do Jellyfin
- [ ] Latest items atualizados

### Dispositivos:
- [ ] Tablet
- [ ] Firestick
- [ ] Emulador Android

### Prioridade: ALTA
### Estimativa: 2-3 horas
""",
        "labels": ["status/todo", "priority/alta", "section/testing", "feature/jellyfin"]
    },

    {
        "title": "[TESTING] Validar reprodução de mídia do Jellyfin",
        "body": """## ✅ Testes: Reprodução de Mídia

### Objetivo:
Garantir que vídeos servidos pelo Jellyfin reproduzem corretamente no `MediaPlayerScreen`.

### Cenários de teste:
- [ ] Filme do Jellyfin reproduz
- [ ] Série do Jellyfin reproduz
- [ ] Qualidade de vídeo adequada (HD/4K)
- [ ] Áudio funciona corretamente
- [ ] Legendas disponíveis (se houver)
- [ ] Pause/Resume funciona
- [ ] Seek funciona
- [ ] Player controls responsivos

### Codecs a testar:
- H.264 (comum)
- HEVC/H.265 (4K)
- VP9 (se disponível)

### Dispositivos:
- [ ] Tablet
- [ ] Firestick

### Acceptance Criteria:
- ✅ Vídeo inicia em menos de 5 segundos
- ✅ Sem buffering excessivo
- ✅ Controles de TV remote funcionam

### Prioridade: ALTA
### Estimativa: 2-3 horas
""",
        "labels": ["status/todo", "priority/alta", "section/testing", "feature/jellyfin"]
    },

    # ============ DOCUMENTAÇÃO ============
    {
        "title": "[DOCS] Documentar setup e uso do Jellyfin no README",
        "body": """## 📖 Documentação: README

### Objetivo:
Adicionar seção completa sobre integração Jellyfin no README do projeto.

### Conteúdo a adicionar:
- [ ] Pré-requisitos (servidor Jellyfin instalado)
- [ ] Como obter credenciais
- [ ] Configuração do `.env`
- [ ] Como encontrar Library ID
- [ ] Troubleshooting comum
- [ ] Screenshots da integração

### Exemplo de documentação:
\`\`\`markdown
## 🐙 Integração Jellyfin

### Requisitos:
- Servidor Jellyfin instalado e acessível
- Conta de usuário com permissões de leitura

### Configuração:
1. Edite o arquivo `.env`
2. Adicione as variáveis:
   \`\`\`
   JELLYFIN_URL=http://seu-servidor:8096
   JELLYFIN_USERNAME=seu_usuario
   JELLYFIN_PASSWORD=sua_senha
   \`\`\`
3. Reinicie o app
\`\`\`

### Prioridade: MÉDIA
### Estimativa: 1 hora
""",
        "labels": ["status/todo", "priority/média", "section/documentation", "feature/jellyfin"]
    },
]

print(f"📝 Criando {len(issues)} issues para integração Jellyfin...\n")

created = 0
failed = 0

for issue_data in issues:
    try:
        issue = repo.create_issue(
            title=issue_data["title"],
            body=issue_data["body"],
            labels=issue_data["labels"]
        )
        print(f"✅ #{issue.number} - {issue_data['title']}")
        created += 1
    except Exception as e:
        print(f"❌ Erro ao criar '{issue_data['title'][:50]}': {str(e)}")
        failed += 1

print(f"\n✨ Resumo: {created} issues criadas, {failed} erros")
print(f"\n🎉 Acesse: https://github.com/{REPO_OWNER}/{REPO_NAME}/issues")
