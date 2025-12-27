TÍTULO: Adicionar cache local de resultados TMDB (persistente)

DESCRIÇÃO:
Contexto:
  O app faz muitas buscas ao TMDB para títulos similares, causando latência e repetição de requests. Um cache local reduzirá chamadas e acelerará enriquecimento.

O que precisa ser feito:
  - Implementar um cache simples de key -> TmdbMetadata (key = normalized title + year + type), persistido em SharedPreferences ou arquivo JSON.
  - Usar esse cache antes de chamar `TmdbService.searchContent`.
  - Incluir política de expiração (ex: 30 dias) e endpoint para limpar cache via Settings.

Critérios de aceitação:
  - Hit rate do cache > 30% após primeira execução em um dispositivo típico.
  - Redução mensurável de chamadas TMDB em logs.

LABELS:
- Aplicação Mobile
- Melhoria
- 🟡 Média

MILESTONE - STATUS:
📋 Backlog e Planejamento

MILESTONE - FASE:
Fase 4: Performance e Otimização

REPOSITÓRIO: Click-Channel
RESPONSÁVEL: @dev-responsavel
