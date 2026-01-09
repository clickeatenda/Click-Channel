TÍTULO: Habilitar enriquecimento TMDB para todas as listas (Latest / Paginadas)

DESCRIÇÃO:
Contexto:
  Atualmente o enriquecimento TMDB está sendo aplicado apenas aos banners/destaques. Listas paginadas e a listagem de "últimos adicionados" usam o cache M3U e não recebem TMDB, gerando discrepância entre a capa e a tela de detalhe.

O que precisa ser feito:
  - Garantir que o `M3uService` aplique enriquecimento TMDB nas listas principais (latest, paged) após o cache ser carregado.
  - Adicionar enriquecimento assíncrono que atualize `_movieCache` com os itens enriquecidos assim que disponíveis.

Critérios de aceitação:
  - Capas e listas exibem rating e sinopse do TMDB para os primeiros itens (amostra de 200) sem necessidade de abrir o detalhe.
  - Logs mostram `ContentEnricher` sendo executado para listas paginadas.
  - Nenhum bloqueio perceptível ao UI (enriquecimento em background).

Impacto / Benefício:
  - Consistência entre capa e detalhe; melhor experiência do usuário.

LABELS:
- Aplicação Mobile
- Melhoria
- 🟠 Alta

MILESTONE - STATUS:
🔧 Em Desenvolvimento

MILESTONE - FASE:
Fase 4: Performance e Otimização

REPOSITÓRIO: Click-Channel
RESPONSÁVEL: @dev-responsavel
