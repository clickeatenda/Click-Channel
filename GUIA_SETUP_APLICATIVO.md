# 🎯 Guia de Setup Completo do Aplicativo

## Estado Atual (29/12/2024)

✅ **APP INSTALADO E FUNCIONANDO:**
- APK buildado com sucesso (79.1MB)
- Instalado em Firestick (192.168.3.110:5555)
- Instalado em Tablet (192.168.3.155:39453)

⚠️ **STATUS INICIAL:**
- ❌ M3U playlist: **NÃO CONFIGURADA** (esperado na primeira instalação)
- ❌ TMDB API key: **INVÁLIDA/EXPIRADA (erro 401)**
- ✅ Estrutura do app: funcionando corretamente
- ✅ Cache management: funcionando
- ✅ TMDB init: executado (mas key inválida)

---

## 🚀 Próximos Passos (OBRIGATÓRIO)

### 1. Configurar URL da Playlist M3U

1. **Abra o app no Firestick/Tablet**
2. **Vá para Settings (Configurações)**
3. **Na seção "Playlist Configuration":**
   - Cole a URL da sua playlist M3U
   - Clique em **"Test Playlist"** (opcional, para verificar se a URL é válida)
   - Clique em **"Save"**

**Resultado esperado:**
- App será reiniciado com a playlist carregada
- Categorias de Filmes e Séries devem aparecer em **segundos**
- Seção "Destaques" mostrará posters TMDB (se API key válida)

---

### 2. Configurar TMDB API Key (Opcional, para Ratings/Destaques)

1. **Abra o app e vá para Settings**
2. **Na seção "TMDB Configuration":**
   - Cole sua chave TMDB válida
   - Clique em **"Test API Key"** (verificar validade)
   - Clique em **"Save"**

**Resultado esperado:**
- Ratings/reviews TMDB aparecerão nos detalhes dos filmes
- Destaques na Home carregarão com imagens TMDB

> ⚠️ **IMPORTANTE:** A chave JWT no `.env` atual está expirada. Você pode:
> - Obter uma nova em [TMDB API](https://www.themoviedb.org/settings/api)
> - Usar a interface de Settings do app (recomendado)

---

## 📋 Checklist de Funcionalidade

Após configurar playlist e API key:

- [ ] M3U categories (Filmes, Séries) carregam em **< 5 segundos**
- [ ] Destaques Home mostram posters TMDB
- [ ] Clique em categoria → lista de conteúdo carrega
- [ ] Clique em filme/série → player inicia
- [ ] Settings permite alterar/testar URL e API key

---

## 🔧 Troubleshooting

### "Categorias não aparecem após salvar playlist"
- **Verifique:** URL da playlist é válida? (teste no navegador)
- **Tente:** 
  1. Volte para Settings
  2. Clique "Clear Cache"
  3. Cole novamente a URL e "Save"
  4. Aguarde 5-10 segundos

### "TMDB ratings não aparecem / erro 401"
- **Cause:** Chave API TMDB inválida/expirada
- **Fix:**
  1. Gere nova chave em [TMDB](https://www.themoviedb.org/settings/api)
  2. Cole em Settings → "TMDB Configuration" → "API Key"
  3. Clique "Test API Key"
  4. Se sucesso: "Save"

### "App fecha ao abrir"
- **Tente:** Reinstalar APK
- **Colete logs:** `adb logcat -d > logs.txt` (para diagnóstico)

---

## 📊 Arquitetura Atual (Restaurada)

```
App Startup:
  1. Prefs.init()                    (carrega SharedPreferences)
  2. TmdbService.init()               (TMDB config → Prefs/fallback .env)
  3. M3uService.preloadCategories()   (background, não bloqueia)
  4. EpgService.loadFromCache()       (background)
  5. UI carrega                       (com dados do cache ou em tempo real)
```

**Fluxo de Dados:**
```
Settings (TMDB API Key, M3U URL)
    ↓
Prefs (SharedPreferences - persistência)
    ↓
TmdbService / M3uService
    ↓
Cache (Disco: JSON do TMDB, M3U categorias)
    ↓
UI (Home/Movies/Series/Details)
```

---

## 💡 Notas Técnicas

- **Primeira execução:** App limpa cache automaticamente (sem playlist = sem dados)
- **Cache M3U:** Salvo em disco para carregamento rápido subsequente
- **Cache TMDB:** JSON persistido em disco, validado na init
- **Paralelização:** ContentEnricher executa em background com `Future.wait`
- **Atualização de config:** TmdbService stream `onConfigChanged` dispara UI update

---

## 📱 Dispositivos

| Dispositivo | IP/Porta | Status |
|-----------|----------|---------|
| Firestick | 192.168.3.110:5555 | ✅ APK instalado |
| Tablet    | 192.168.3.155:39453 | ✅ APK instalado |

---

**Próximo:** Siga os passos acima e reporte qualquer problema! 🚀
