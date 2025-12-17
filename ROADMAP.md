# 🚀 Click Channel - Roadmap de Melhorias

> Última atualização: 17/12/2025  
> Versão atual: 1.0.0

---

## 📋 Legenda de Status

- [ ] Pendente
- [x] Implementado
- [~] Em andamento
- [!] Bloqueado

---

## 🔴 Prioridade Alta

### Segurança
- [ ] Remover `.env` do histórico do git
- [ ] Adicionar `.env` ao `.gitignore`
- [ ] Migrar credenciais sensíveis para `flutter_secure_storage`
- [ ] Implementar certificate pinning para API calls

### EPG (Guia de Programação)
- [ ] Parser de EPG (XMLTV format)
- [ ] Tela de programação por canal
- [ ] Indicador "Ao Vivo" / "Em breve"
- [ ] Notificação de programa favorito

---

## 🟡 Prioridade Média

### Performance
- [ ] Lazy loading de imagens nos cards
- [ ] Shimmer/skeleton loading nos carrosséis
- [ ] Cache de imagens com tamanho limitado (100MB max)
- [ ] Compressão de thumbnails em memória
- [ ] Paginação virtual em listas grandes (+1000 itens)

### Busca Avançada
- [ ] Filtro por ano de lançamento
- [ ] Filtro por gênero
- [ ] Filtro por qualidade (4K, FHD, HD, SD)
- [ ] Histórico de buscas recentes
- [ ] Sugestões de busca (autocomplete)

### UX/Interface
- [ ] Splash screen animada com logo
- [ ] Indicador de carregamento elegante (shimmer)
- [ ] Feedback sonoro na navegação TV
- [ ] Barra de progresso no card "Continuar Assistindo"
- [ ] Animações de transição entre telas

---

## 🟢 Prioridade Baixa

### Funcionalidades Extras
- [ ] Modo picture-in-picture (PiP) para canais
- [ ] Download para assistir offline
- [ ] Múltiplos perfis de usuário
- [ ] Controle parental com PIN
- [ ] Legendas externas (.srt, .ass, .vtt)
- [ ] Sincronização de favoritos na nuvem
- [ ] Cast para Chromecast/AirPlay

### Android TV / Fire TV
- [ ] Integração com Leanback launcher
- [ ] Suporte a comandos de voz (Alexa/Google)
- [ ] Recomendações na home do Android TV
- [ ] Channel Shortcuts (atalhos rápidos)
- [ ] Watch Next integration

### Código e Arquitetura
- [ ] Testes unitários (coverage > 70%)
- [ ] Testes de widget
- [ ] Migrar para Riverpod ou Bloc
- [ ] Documentação de API inline
- [ ] Tratamento de erros granular
- [ ] Logs estruturados com níveis

### Estabilidade
- [ ] Retry automático em falhas de rede
- [ ] Reconexão automática do player
- [ ] Firebase Crashlytics integration
- [ ] Analytics (Firebase/Mixpanel)
- [ ] Monitoramento de performance

---

## 📱 Compatibilidade de Plataformas

| Plataforma | Status | Testado | Notas |
|------------|--------|---------|-------|
| Android TV | ✅ | [x] | Fire TV Stick, Mi Box |
| Android Tablet | ✅ | [x] | Xiaomi Pad |
| Android Phone | ✅ | [ ] | A testar |
| iOS/iPadOS | ⚠️ | [ ] | media_kit compatível |
| Web | ⚠️ | [ ] | Limitações do media_kit |
| Windows | ⚠️ | [ ] | A testar |
| macOS | ⚠️ | [ ] | A testar |
| Linux | ⚠️ | [ ] | A testar |

---

## 📝 Histórico de Versões

### v1.0.0 (17/12/2025)
- [x] Player com media_kit (4K/HDR)
- [x] Seleção de faixa de áudio
- [x] Seleção de legendas
- [x] Ajuste de tela (5 modos)
- [x] Histórico de assistidos
- [x] Continuar assistindo
- [x] Filtros de qualidade
- [x] Cache persistente de playlist
- [x] Nova logo e ícone
- [x] Renomeado para Click Channel

---

## 🎯 Próximos Passos Sugeridos

1. **Sprint 1 (Segurança)**
   - Corrigir vazamento de .env
   - Implementar secure storage

2. **Sprint 2 (EPG)**
   - Parser XMLTV
   - UI de programação

3. **Sprint 3 (Performance)**
   - Lazy loading
   - Cache de imagens

4. **Sprint 4 (Busca)**
   - Filtros avançados
   - Autocomplete

---

## 📊 Métricas de Qualidade

| Métrica | Atual | Meta |
|---------|-------|------|
| Test Coverage | 0% | 70% |
| Crash-free users | N/A | 99.5% |
| App size | 92MB | < 80MB |
| Cold start time | ~3s | < 2s |
| Memory usage | N/A | < 200MB |

---

*Documento gerado automaticamente. Atualize conforme implementações.*
