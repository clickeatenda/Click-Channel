# 🔀 COMPARATIVO: master vs feature/stitch-design-implementation

**Data:** 15/12/2025

---

## 📊 RESUMO RÁPIDO

| Aspecto | `master` | `feature/stitch-design-implementation` |
|---------|----------|-------|
| **Status** | Upstream limpo | Backend conectado ✅ |
| **Backend URL** | Via `.env` (dinâmico) | Hardcoded em ApiClient |
| **API Service** | `ApiClient` (Dio) | `ApiService` (http) + `ApiClient` (Dio) |
| **Dados Reais** | ❌ Placeholders | ✅ Do backend |
| **Autenticação** | ✅ Implementada | ✅ Implementada + testada |
| **Conteúdo** | ❌ Falta integração | ✅ Integrado |
| **Dependências** | 10 packages | 9 packages |
| **Últimos commits** | 15/12 (fix: unused vars) | 13/12 (test: frontend page) |

---

## 🔧 DIFERENÇAS TÉCNICAS

### **1. API Client Strategy**

#### **master**
```dart
// lib/core/api/api_client.dart
import 'config.dart';

class ApiClient {
  // Lê de .env via Config
  static String get baseUrl => '${Config.backendUrl}/api';
}
```

```dart
// lib/core/config.dart
class Config {
  static String get backendUrl {
    try {
      return dotenv.env['BACKEND_URL'] ?? 'http://192.168.3.251:4000';
    } catch (_) {
      return 'http://192.168.3.251:4000'; // Fallback
    }
  }
}
```

**Vantagens:**
✅ Configuração dinâmica via `.env`  
✅ Diferentes URLs por ambiente (dev/staging/prod)  
✅ Segredo não hardcoded  

**Desvantagens:**
❌ Depende de Flutter Dotenv  
❌ Mais complex  

---

#### **feature/stitch-design-implementation**
```dart
// lib/core/api/api_client.dart
class ApiClient {
  // Hardcoded direto
  static const String baseUrl = 'http://192.168.3.251:4000/api';
}

// lib/data/api_service.dart
const String SERVER_IP = "192.168.3.251";
const String BACKEND_URL = "http://$SERVER_IP:4000";
```

**Vantagens:**
✅ Simples e direto  
✅ Menos dependências  
✅ Funciona imediatamente  

**Desvantagens:**
❌ Hardcoded (não ideal para produção)  
❌ Requer rebuild para mudar URL  
❌ Difícil testar em ambientes diferentes  

---

### **2. HTTP Clients - Dupla Estratégia**

#### **master**
```
┌─────────────────────────┐
│  Todas as Requisições   │
├─────────────────────────┤
│  ApiClient (Dio)        │
│  - Interceptors         │
│  - Token management     │
│  - Error handling       │
└─────────────────────────┘
```

#### **feature/stitch-design-implementation**
```
┌──────────────────────────────────────────┐
│  Requisições de Conteúdo                 │
├──────────────────────────────────────────┤
│  ApiService (http package)               │
│  - Simples GET requests                  │
│  - Sem token (dados públicos?)           │
│  - Error handling básico                 │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  Requisições de Autenticação             │
├──────────────────────────────────────────┤
│  ApiClient (Dio)                         │
│  - POST login/register                   │
│  - Token storage                         │
│  - Interceptors                          │
└──────────────────────────────────────────┘
```

**Por que dois?**
- `ApiService` para dados de conteúdo (rápido, sem overhead)
- `ApiClient` para operações autenticadas (com token interceptor)

---

### **3. Dependências (pubspec.yaml)**

#### **master** (10 packages)
```yaml
http: ^1.2.0
flutter_dotenv: ^5.0.2         # ← Config dinâmica
dio: ^5.3.1
flutter_secure_storage: ^9.0.0
provider: ^6.0.0
video_player: ^2.8.2
chewie: ^1.7.1
cached_network_image: ^3.3.1
google_fonts: ^6.2.1
cupertino_icons: ^1.0.2
```

#### **feature/stitch-design-implementation** (9 packages)
```yaml
http: ^1.2.0                   # ← Para ApiService
video_player: ^2.8.2
chewie: ^1.7.1
cached_network_image: ^3.3.1
google_fonts: ^6.2.1
cupertino_icons: ^1.0.2
# Nota: Sem flutter_dotenv, sem provider no pubspec visível
# (Pode estar em pubspec.lock de forma transitória)
```

---

### **4. Theme Colors**

#### **master** (app_colors.dart)
```dart
primary: #E11D48        // Rosa vibrante (ClickFlix brand)
accent: #EC4C63         // Rosa clara
backgroundDark: #111318
backgroundDarker: #0F1620
```

#### **feature/stitch-design-implementation** (app_colors.dart)
```dart
primary: #135bec        // Azul Stitch
primaryLight: #38bdf8   // Azul claro
backgroundDark: #101622
backgroundDarker: #0f172a
```

**Mudança:** De rosa (ClickFlix) para azul (Stitch/Channel design)

---

### **5. Type System & Theme**

#### **master**
- Typography: Embutida em TextTheme do ThemeData
- Colors: Apenas cores
- Tipografia dinâmica de Material 3

#### **feature/stitch-design-implementation**
- **Novo:** `app_typography.dart` com estilos predefinidos
- Classes como `AppTypography.headlineMedium`, `bodyLarge`, etc.
- Mais consistência e reutilização

---

### **6. Arquivos Exclusivos de Cada Branch**

#### **Apenas em master**
```
lib/core/config.dart                    # Config via .env
lib/screens/detail_screens.dart         # Telas genéricas de detalhe
.env, .env.example                      # Configuração dinâmica
```

#### **Apenas em feature/stitch-design-implementation**
```
lib/core/theme/app_typography.dart      # Sistema de tipografia
lib/data/api_service.dart               # Serviço de API com http
```

#### **Significativamente Modificados**
```
lib/main.dart                           # Estrutura de setup
lib/screens/                            # Todas as telas (layout/design)
lib/widgets/                            # Todos os widgets
```

---

## 🚀 FLUXOS DE DADOS COMPARADOS

### **Em master: Carregamento de Dados**
```
Screen (initState)
    ↓ (Falta implementação)
❌ Placeholder data apenas
```

### **Em feature/stitch-design-implementation: Carregamento de Dados**
```
CategoryScreen (initState)
    ↓
_loadItems()
    ↓
ApiService.fetchCategoryItems(categoryName, type, limit: 100)
    ↓
GET http://192.168.3.251:4000/api/items?category=Ação&type=movies...
    ↓
Backend responde com: [ContentItem, ContentItem, ...]
    ↓
setState()
    ↓
GridView renderiza itens
    ↓
User clica em item → PlayerScreen ou SeriesDetailScreen
```

---

## 📊 ESTADO DO DESENVOLVIMENTO

### **master**
```
✅ UI/UX - 100%
✅ Navegação - 100%
✅ Autenticação (setup) - 80%
❌ Integração com backend - 5%
❌ Carregamento de dados reais - 0%
```

**Tipo:** Framework/Setup limpo

### **feature/stitch-design-implementation**
```
✅ UI/UX - 100% (com Stitch design)
✅ Navegação - 100%
✅ Autenticação - 100% (completa)
✅ Integração com backend - 80%
✅ Carregamento de dados reais - 60%
⚠️ Favoritos/Histórico - 0% (backend integration)
```

**Tipo:** Implementação funcional

---

## 🎯 QUAL USAR?

### **Use `master` SE:**
- [ ] Estiver fazendo setup inicial
- [ ] Quiser configuração por `.env`
- [ ] Preferir uma base limpa para customização
- [ ] Backend ainda não está pronto

### **Use `feature/stitch-design-implementation` SE:**
- [x] Backend já está rodando em container
- [x] Quer dados reais funcionando imediatamente
- [x] Precisa de carregamento de conteúdo
- [x] Quer testar fluxos completos
- [x] Backend está em 192.168.3.251:4000

---

## 🔄 ESTRATÉGIA RECOMENDADA

### **Opção 1: Mergear (Recomendada)**
```bash
# No desenvolvimento atual em master
git merge feature/stitch-design-implementation

# Resultado: Melhor dos dois mundos
- Config dinâmica do master
- Dados reais do stitch-design-implementation
```

### **Opção 2: Cherry-pick seletivo**
```bash
# Pegar apenas os arquivos que funcionam do stitch
git checkout feature/stitch-design-implementation -- lib/data/api_service.dart
git checkout feature/stitch-design-implementation -- lib/screens/
git checkout feature/stitch-design-implementation -- lib/core/theme/app_typography.dart

# Manter Config.dart e .env do master
```

### **Opção 3: Manter separadas**
```bash
# feature/stitch-design-implementation: Desenvolvimento com dados reais
# master: Releases e builds finalizadas
# develop: Integração contínua
```

---

## 📝 CHECKLIST: O QUE PRECISA SER FEITO

### **Para trazer o stitch para master (ou produção):**

- [ ] Removar hardcoded URLs, voltar a usar `.env`
- [ ] Consolidar `ApiService` + `ApiClient` em uma estratégia
- [ ] Implementar retry logic
- [ ] Adicionar loading states (skeleton screens)
- [ ] Implementar tratamento de erro 401 (redirecionar para login)
- [ ] Testar com backend real
- [ ] Adicionar certificação pinning (TLS)
- [ ] Documentar endpoints esperados
- [ ] Testes unitários
- [ ] CI/CD setup

---

## 🎓 LIÇÕES APRENDIDAS

1. **Dois Clients HTTP:** Pode ser uma bad practice, melhor consolidar
2. **Config Dinâmica:** Essencial para diferentes ambientes
3. **Armazenamento Seguro:** Já bem implementado em ambos
4. **Design System:** TypeSystem + Colors bem estruturado
5. **Integração:** Fácil quando backend está pronto

---

## 📞 PRÓXIMAS AÇÕES

1. [ ] Contactar time que está mantendo backend em container
2. [ ] Obter documentação de endpoints
3. [ ] Validar formato de resposta de cada endpoint
4. [ ] Decidir entre merge ou branch strategy
5. [ ] Setup de CI/CD

---

**Comparativo Gerado:** 15/12/2025  
**Para:** Análise de estratégia de integração  
**Status:** Pronto para decisão de merge
