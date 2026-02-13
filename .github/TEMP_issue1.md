**Contexto:**
Usuário reportou que a regra de 95% era muito alta. Muitos usuários assistiam 80-90% do conteúdo mas não era marcado como concluído.

**Implementação:**
- Alterada threshold de 95% para 80% em `watch_history_service.dart`
- Build v10 deployado em produção (Tablet + Fire Stick)

**Checklist:**
- [x] Reduzir threshold de 95% para 80%
- [x] Testar em filmes e séries
- [x] Deploy build v10

**Impacto:**
Melhora UX ao marcar conteúdo como assistido mais cedo, alinhado com expectativa dos usuários.
