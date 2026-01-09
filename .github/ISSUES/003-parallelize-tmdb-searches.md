TÍTULO: Paralelizar buscas TMDB com limite de concorrência

DESCRIÇÃO:
Contexto:
  O `ContentEnricher` realiza buscas sequenciais por variações de título, o que é robusto mas lento. Paralelizar várias buscas permitiria enriquecer mais rapidamente.

O que precisa ser feito:
  - Implementar um executor/semaphore para executar N buscas em paralelo (sugestão: N = 6-8), respeitando rate limits.
  - Garantir retries e backoff exponencial para falhas/429.
  - Medir latência e falhas após implementação.

Critérios de aceitação:
  - Tempo médio para enriquecer 200 itens reduzido em >2x.
  - Nenhum aumento de erros 429 no log após aplicar limite adequado.

LABELS:
- Aplicação Mobile
- Refatoração
- 🟠 Alta

MILESTONE - STATUS:
🔧 Em Desenvolvimento

MILESTONE - FASE:
Fase 4: Performance e Otimização

REPOSITÓRIO: Click-Channel
RESPONSÁVEL: @dev-responsavel
