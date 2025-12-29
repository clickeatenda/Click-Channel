# 🔧 Correção - Destaques TMDB vs M3U (29/12/2025)

## Problema Relatado

❌ **Banners de filmes e séries em destaque:**
- Estavam exibindo **canais M3U** (em vez de conteúdo TMDB)
- Isso estava funcionando antes, mas deixou de funcionar

## Análise da Causa

Na `_HomeBodyState._load()` (home_screen.dart):

### Código Incorreto (Antes):
```dart
// ❌ ERRADO: Carregar destaques M3U e "enriquecer" com TMDB
final results = await Future.wait([
  M3uService.getCuratedFeaturedPrefer('movie', ...),  // ← Destaques M3U!
  M3uService.getCuratedFeaturedPrefer('series', ...),
  M3uService.getCuratedFeaturedPrefer('channel', ...),
]);

// Depois enriquece M3U com TMDB (mas origen é M3U)
enrichedMovies = await ContentEnricher.enrichItems(results[0]);
```

**Problema:**
- Os destaques eram **originários de M3U** (canais de filmes)
- O enriquecimento TMDB tentava melhorar os M3U items, mas não substituía a origem
- Resultado: canais M3U sendo mostrados como "destaques de filmes"

### Código Correto (Depois):
```dart
// ✅ CORRETO: Carregar destaques DIRETAMENTE do TMDB
final tmdbResults = await Future.wait([
  TmdbService.getPopularMovies(page: 1),  // ← Destaques TMDB!
  TmdbService.getPopularSeries(page: 1),
]);

// Converter TmdbMetadata para ContentItem
List<ContentItem> tmdbMovies = tmdbResults[0]
  .take(6)
  .map((m) => ContentItem(
    title: m.title,
    image: 'https://image.tmdb.org/t/p/w342${m.posterPath}',
    group: 'TMDB Popular',
    ...
  ))
  .toList();
```

**Vantagens:**
1. ✅ Destaques vêm DIRETAMENTE do TMDB (não M3U)
2. ✅ Não dependem de playlist M3U configurada
3. ✅ Sempre mostram conteúdo relevante (trending/popular)
4. ✅ Fallback para M3U se TMDB falhar

---

## Mudanças Implementadas

### Arquivo: `lib/screens/home_screen.dart`

#### 1. Adicionar Import TMDB
```dart
import '../data/tmdb_service.dart';  // ← Adicionado
```

#### 2. Refatorar `_HomeBodyState._load()`
```dart
// Buscar destaques do TMDB em paralelo
final tmdbResults = await Future.wait([
  TmdbService.getPopularMovies(page: 1),
  TmdbService.getPopularSeries(page: 1),
]);

// Converter TmdbMetadata para ContentItem
List<ContentItem> tmdbMovies = tmdbResults[0]
  .take(6)
  .map((m) => ContentItem(
    title: m.title,
    url: '', // TMDB items não têm URL de streaming
    image: m.posterPath != null ? 'https://image.tmdb.org/t/p/w342${m.posterPath}' : '',
    group: 'TMDB Popular',
    type: 'movie',
    id: m.id.toString(),
    rating: m.rating,
    year: m.releaseDate?.substring(0, 4) ?? '',
    description: m.overview ?? '',
  ))
  .toList();

List<ContentItem> tmdbSeries = tmdbResults[1]
  .take(6)
  .map(...)
  .toList();

// Carrega canais M3U se houver playlist (SEPARADO de destaques TMDB)
List<ContentItem> channels = [];
final hasM3u = Config.playlistRuntime != null && Config.playlistRuntime!.isNotEmpty;
if (hasM3u) {
  channels = await M3uService.getCuratedFeaturedPrefer('channel', ...);
}

setState(() {
  featuredMovies = tmdbMovies;   // ← TMDB!
  featuredSeries = tmdbSeries;   // ← TMDB!
  featuredChannels = channels;   // ← M3U (apenas canais)
  loading = false;
});
```

#### 3. Error Handling
```dart
try {
  // Carrega TMDB destaques
  ...
} catch (e) {
  print('⚠️ Erro ao carregar destaques TMDB: $e');
  // Fallback para M3U se TMDB falhar
  if (hasM3u) {
    try {
      final results = await Future.wait([
        M3uService.getCuratedFeaturedPrefer('movie', ...),
        M3uService.getCuratedFeaturedPrefer('series', ...),
        ...
      ]);
      // Usa M3U como fallback
    } catch (_) {
      // Retorna listas vazias se tudo falhar
    }
  }
}
```

---

## 📊 Antes vs Depois

### ❌ Antes (Incorreto)
```
Home Screen
├─ Assistindo/Últimos
├─ Filmes em Destaque
│  └─ [Canal 1, Canal 2, Canal 3] ← ERRADO: Canais M3U!
├─ Séries em Destaque
│  └─ [Canal A, Canal B] ← ERRADO: Canais M3U!
└─ Canais
   └─ [Canal X, Canal Y]
```

### ✅ Depois (Correto)
```
Home Screen
├─ Assistindo/Últimos
├─ Filmes em Destaque
│  └─ [Filme Popular 1 (TMDB), Filme Popular 2 (TMDB)] ← CORRETO!
├─ Séries em Destaque
│  └─ [Série Popular A (TMDB), Série Popular B (TMDB)] ← CORRETO!
└─ Canais
   └─ [Canal X (M3U), Canal Y (M3U)]
```

---

## 🧪 Testes

### Cenário 1: TMDB Configurado + Playlist M3U
✅ Resultado esperado:
- Destaques TMDB carregam (filmes + séries)
- Canais M3U aparecem na seção "Canais em destaque"

### Cenário 2: TMDB Não Configurado + Playlist M3U
✅ Resultado esperado (Fallback):
- Destaques caem para M3U (se fallback ativado)
- Canais M3U aparecem

### Cenário 3: Sem Playlist M3U
✅ Resultado esperado:
- Destaques TMDB carregam (independente de M3U)
- Sem canais (porque não há M3U)

---

## 🔄 Lógica de Inicialização (Agora)

```
_HomeBodyState.initState()
    ↓
_load()
    ├─ Carregar histórico (WatchHistoryService)
    │  ├─ watchedItems
    │  └─ watchingItems
    │
    ├─ Carregar destaques TMDB (sempre)
    │  ├─ TmdbService.getPopularMovies()
    │  └─ TmdbService.getPopularSeries()
    │
    ├─ Se M3U disponível:
    │  └─ Carregar canais M3U
    │
    ├─ Se TMDB falhar (fallback):
    │  └─ Usar M3U para filmes + séries
    │
    └─ setState() → UI atualiza
```

---

## 📝 Notas Técnicas

1. **ContentItem requer `url` obrigatoriamente**
   - TMDB items usam `url: ''` (não têm URL de streaming)
   - Widget que exibe destaques deve lidar com URLs vazias

2. **Separação de Responsabilidades**
   - Destaques TMDB: via `TmdbService.getPopular*()`
   - Canais M3U: via `M3uService.getCuratedFeatured()`
   - Não misturar fontes (antes estava fazendo isso)

3. **Cache de Imagens TMDB**
   - URLs: `https://image.tmdb.org/t/p/w342${posterPath}`
   - URLs: `https://image.tmdb.org/t/p/w1280${backdropPath}`
   - Sem auth requerida

4. **Error Handling Robusto**
   - Tenta TMDB primeiro
   - Se falha, tenta M3U (fallback)
   - Se ambas falham, retorna listas vazias

---

## ✅ Status

**Build:** Em progresso (compilando APK com correção)  
**Teste:** Aguardando build concluir  
**Deploy:** Após validação do build

---

**Data:** 29/12/2025  
**Versão:** Fix TMDB Destaques
