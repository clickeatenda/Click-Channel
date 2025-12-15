# 🔗 GUIA PRÁTICO: COMO O FRONTEND CONECTA NO BACKEND

**Branch:** `feature/stitch-design-implementation`  
**Backend:** http://192.168.3.251:4000/api  
**Data:** 15/12/2025

---

## 🎯 EXEMPLO 1: Login (Autenticação)

### **Flow Visual**
```
┌──────────────┐
│ LoginScreen  │
│              │
│ Email: ...   │
│ Password: .. │
│ [Login Btn]  │
└──────────────┘
       │
       │ User submits
       ▼
┌──────────────────────────────────────────┐
│ login_screen.dart (line ~120)            │
│                                          │
│ authProvider.login(email, password)      │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ AuthProvider.login()                     │
│ (lib/providers/auth_provider.dart)       │
│                                          │
│ await _apiClient.post(                   │
│   '/auth/login',                         │
│   data: {                                │
│     'email': email,                      │
│     'password': password                 │
│   }                                      │
│ )                                        │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ ApiClient (lib/core/api/api_client.dart) │
│                                          │
│ 1. Prepara Dio request                   │
│ 2. Interceptor adiciona Bearer token    │
│ 3. POST http://192.168.3.251:4000/api/  │
│    auth/login                            │
│ 4. Aguarda resposta                      │
└──────────────────────────────────────────┘
       │
       ▼
    Network
       │
       ▼
┌──────────────────────────────────────────┐
│ BACKEND (Container 192.168.3.251:4000)  │
│                                          │
│ POST /api/auth/login                     │
│ {                                        │
│   "email": "user@example.com",          │
│   "password": "pass123"                  │
│ }                                        │
│                                          │
│ ✅ Credenciais válidas                  │
│                                          │
│ Responde:                                │
│ {                                        │
│   "token": "eyJhbGciOiJIUzI1NiIs...",  │
│   "user": {                              │
│     "id": "12345",                       │
│     "name": "João Silva",                │
│     "email": "user@example.com"          │
│   }                                      │
│ }                                        │
└──────────────────────────────────────────┘
       │
       ▼
    Network
       │
       ▼
┌──────────────────────────────────────────┐
│ ApiClient recebe resposta (status 200)   │
│                                          │
│ Response {                               │
│   statusCode: 200,                       │
│   data: {                                │
│     "token": "...",                      │
│     "user": {...}                        │
│   }                                      │
│ }                                        │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ AuthProvider processa resposta            │
│                                          │
│ _token = response.data['token']          │
│ _userId = response.data['user']['id']    │
│ _userName = response.data['user']['name']│
│ _userEmail = response.data['user']['email']
│                                          │
│ Salva em FlutterSecureStorage:           │
│ await _secureStorage.write(              │
│   key: 'auth_token',                     │
│   value: _token                          │
│ )                                        │
│                                          │
│ notifyListeners() → UI atualiza          │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ main.dart (initialRoute)                 │
│                                          │
│ if (authProvider.isAuthenticated)        │
│   → AppRoutes.home                       │
│ else                                     │
│   → AppRoutes.login                      │
│                                          │
│ Navigator → HomeScreen                   │
└──────────────────────────────────────────┘
       │
       ▼
    ✅ LOGADO COM SUCESSO
```

### **Código Relevante**

**1. LoginScreen chamando login:**
```dart
// lib/screens/login_screen.dart (~line 120)
onPressed: () async {
  final success = await context
    .read<AuthProvider>()
    .login(emailController.text, passwordController.text);
  
  if (success && mounted) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }
}
```

**2. AuthProvider.login():**
```dart
// lib/providers/auth_provider.dart (~line 38)
Future<bool> login(String email, String password) async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();
  
  try {
    final response = await _apiClient.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    
    if (response.statusCode == 200) {
      _token = response.data['token'];
      _userId = response.data['user']['id'].toString();
      _userName = response.data['user']['name'];
      _userEmail = response.data['user']['email'];
      
      // Salva em storage seguro
      await _secureStorage.write(key: 'auth_token', value: _token!);
      await _secureStorage.write(key: 'user_id', value: _userId!);
      await _secureStorage.write(key: 'user_name', value: _userName!);
      await _secureStorage.write(key: 'user_email', value: _userEmail!);
      
      _isLoading = false;
      notifyListeners();
      return true;
    }
  } catch (e) {
    _errorMessage = 'Erro ao fazer login: ${e.toString()}';
    print('Login error: $e');
  }
  
  _isLoading = false;
  notifyListeners();
  return false;
}
```

**3. ApiClient.post() com Interceptor:**
```dart
// lib/core/api/api_client.dart (~line 50)
Future<Response> post(
  String endpoint, {
  required Map<String, dynamic> data,
}) async {
  try {
    final response = await _dio.post(endpoint, data: data);
    return response;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}

// Interceptor adicionado no constructor (~line 20)
_dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        final token = await _secureStorage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        print('Erro ao ler token: $e');
      }
      return handler.next(options);
    },
    // ...
  ),
);
```

---

## 🎯 EXEMPLO 2: Carregar Conteúdo de Categoria

### **Flow Visual**
```
┌──────────────────────┐
│ CategoryScreen       │
│ (initState chamado)  │
└──────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ _CategoryScreenState._loadItems()        │
│                                          │
│ final data = await ApiService           │
│   .fetchCategoryItems(                   │
│     'Ação',          ← categoryName      │
│     'movies',        ← type              │
│     limit: 100                           │
│   )                                      │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ ApiService (lib/data/api_service.dart)  │
│                                          │
│ static Future<List<ContentItem>>         │
│ fetchCategoryItems(                      │
│   String category,                       │
│   String type,                           │
│   {int limit = 15}                       │
│ ) async {                                │
│   try {                                  │
│     final uri = Uri.parse(               │
│       'http://192.168.3.251:4000'       │
│       '/api/items'                       │
│       '?category=Ação'                   │
│       '&type=movies'                     │
│       '&page=1'                          │
│       '&limit=100'                       │
│     )                                    │
│                                          │
│     final res = await http.get(uri)      │
│     if (res.statusCode == 200) {         │
│       List list = json.decode(           │
│         res.body                         │
│       )                                  │
│       return list                        │
│         .map((i) =>                      │
│           ContentItem.fromJson(i)        │
│         )                                │
│         .toList()                        │
│     }                                    │
│   } catch (_) {}                         │
│   return []                              │
│ }                                        │
└──────────────────────────────────────────┘
       │
       ▼
    Network HTTP GET
       │
       ▼
┌──────────────────────────────────────────┐
│ BACKEND                                  │
│ GET /api/items?category=Ação&type=      │
│ movies&page=1&limit=100                  │
│                                          │
│ Processa requisição                      │
│ Busca 100 itens da categoria "Ação"      │
│ do tipo "movies"                         │
│                                          │
│ Responde com JSON:                       │
│ [                                        │
│   {                                      │
│     "id": "123",                         │
│     "title": "John Wick 4",              │
│     "url": "https://stream.../video",    │
│     "image": "https://.../poster.jpg",   │
│     "group": "Ação",                     │
│     "type": "movie",                     │
│     "isSeries": false,                   │
│     "rating": 8.7,                       │
│     "year": "2023"                       │
│   },                                     │
│   {                                      │
│     "id": "124",                         │
│     "title": "Mad Max Fury Road",        │
│     ...                                  │
│   },                                     │
│   ... (até 100 itens)                    │
│ ]                                        │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ http.get() retorna Response              │
│                                          │
│ statusCode: 200                          │
│ body: [                                  │
│   {"id": "123", "title": "...", ...},    │
│   ...                                    │
│ ]                                        │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ ContentItem.fromJson() faz parse         │
│                                          │
│ factory ContentItem.fromJson(            │
│   Map<String, dynamic> json              │
│ ) {                                      │
│   return ContentItem(                    │
│     title: json['title'] ??              │
│       "Sem Título",                      │
│     url: json['url'] ?? "",              │
│     image: json['logo'] ?? "",           │
│     group: json['group'] ??              │
│       "Geral",                           │
│     type: json['type'] ?? "movie",       │
│     isSeries: json['isSeries'] ??        │
│       false,                             │
│     id: json['id'] ?? "",                │
│     rating: 8.5,                         │
│     year: "2024",                        │
│   );                                     │
│ }                                        │
│                                          │
│ Resultado: List<ContentItem> com 100     │
│ objetos parseados                        │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ Retorna para _loadItems()                │
│                                          │
│ setState(() {                            │
│   items = data;  ← [ContentItem, ...]    │
│   if (items.isNotEmpty) {                │
│     final withImage =                    │
│       items.where((i) =>                 │
│         i.image.isNotEmpty               │
│       ).toList();                        │
│     bannerItem = withImage.isNotEmpty    │
│       ? withImage[Random()               │
│         .nextInt(withImage.length)]      │
│       : items.first;                     │
│   }                                      │
│   loading = false;                       │
│ })                                       │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ build() é chamado novamente              │
│                                          │
│ if (loading)                             │
│   → CircularProgressIndicator            │
│ else                                     │
│   → SliverGrid com ContentCard widgets   │
│                                          │
│ SliverChildBuilderDelegate:              │
│   for (index, item in items)             │
│     ContentCard(                         │
│       item: item,   ← ContentItem        │
│       onTap: (_) {                       │
│         if (item.isSeries)               │
│           → SeriesDetailScreen           │
│         else                             │
│           → PlayerScreen                 │
│       }                                  │
│     )                                    │
└──────────────────────────────────────────┘
       │
       ▼
    ✅ UI RENDERIZA COM DADOS REAIS
       │
       ▼
┌─────────────────────────────────────────────────┐
│ User vê GridView com:                           │
│                                                 │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│ │ John     │ │ Mad Max  │ │ Tom's    │        │
│ │ Wick 4   │ │ Fury Road│ │ Cat Café │        │
│ │          │ │          │ │          │        │
│ │ 8.7 ⭐   │ │ 9.0 ⭐   │ │ 7.5 ⭐   │        │
│ └──────────┘ └──────────┘ └──────────┘        │
│                                                 │
│ ... (até 100 cards)                            │
└─────────────────────────────────────────────────┘
```

### **Código Relevante**

```dart
// lib/screens/category_screen.dart (~line 20)
class _CategoryScreenState extends State<CategoryScreen> {
  List<ContentItem> items = [];
  bool loading = true;
  
  @override
  void initState() {
    super.initState();
    _loadItems();
  }
  
  Future<void> _loadItems() async {
    // Busca até 100 itens
    final data = await ApiService.fetchCategoryItems(
      widget.categoryName,  // "Ação"
      widget.type,          // "movies"
      limit: 100
    );
    
    if (mounted) {
      setState(() {
        items = data;
        if (items.isNotEmpty) {
          final withImage = items
            .where((i) => i.image.isNotEmpty)
            .toList();
          bannerItem = withImage.isNotEmpty
            ? withImage[Random().nextInt(withImage.length)]
            : items.first;
        }
        loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: loading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary
            )
          )
        : CustomScrollView(
            slivers: [
              // ... SliverAppBar ...
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ContentCard(
                        item: items[index],
                        onTap: (_) {
                          if (items[index].isSeries) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                  SeriesDetailScreen(
                                    item: items[index]
                                  )
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                  PlayerScreen(
                                    url: items[index].url
                                  )
                              ),
                            );
                          }
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
```

---

## 🎯 EXEMPLO 3: Series Details (com Temporadas e Episódios)

### **Flow Simplificado**

```
SeriesDetailScreen
    ↓
initState() → _loadDetails()
    ↓
ApiService.fetchSeriesDetails(widget.item.id)
    ↓
GET /api/series/details?id=123
    ↓
Backend retorna:
{
  "seasons": {
    "Season 1": [
      {id: "ep1", title: "Ep 1", url: "...", ...},
      {id: "ep2", title: "Ep 2", url: "...", ...},
      ...
    ],
    "Season 2": [
      ...
    ]
  }
}
    ↓
SeriesDetails.fromJson() faz parse
    ↓
setState() → UI renderiza DropdownButton de temporadas
    ↓
User seleciona Season → GridView de episódios
    ↓
User clica em episódio → PlayerScreen com URL do episódio
```

---

## 📡 RESUMO DOS ENDPOINTS

### **Autenticação** (ApiClient com Dio)
```
POST /api/auth/login
  ← {email, password}
  → {token, user: {id, name, email}}

POST /api/auth/register
  ← {name, email, password}
  → {token, user: {id, name, email}}
```

### **Conteúdo** (ApiService com http)
```
GET /api/categories?type={type}
  → ["Ação", "Drama", ...]

GET /api/items?category={cat}&type={type}&page={page}&limit={limit}
  → [{id, title, url, image, ...}, ...]

GET /api/series/details?id={id}
  → {seasons: {"Season 1": [...], ...}}
```

---

## 🔐 Token Flow - Como é Mantido

### **Salvamento (após login)**
```
1. Backend retorna token no response
   ↓
2. AuthProvider armazena em:
   - Memory (_token variable)
   - FlutterSecureStorage (chave: 'auth_token')
   ↓
3. Próximas requisições: Interceptor lê de secure storage
   ↓
4. Adiciona header: Authorization: Bearer {token}
```

### **Leitura em Próximas Requisições**
```
ApiClient.post() chamado
    ↓
InterceptorsWrapper.onRequest()
    ↓
const token = await _secureStorage.read(key: 'auth_token')
    ↓
if (token != null)
  options.headers['Authorization'] = 'Bearer $token'
    ↓
Request enviada COM token no header
```

---

## 🚨 Tratamento de Erros

### **Se Rede Falhar**
```dart
try {
  final response = await _apiClient.post(...)
} catch (e) {
  _errorMessage = 'Erro ao fazer login: ${e.toString()}'
  // Exibe erro para user
}
```

### **Se Backend Retornar 401 (Token Expirado)**
```dart
onError: (error, handler) {
  if (error.response?.statusCode == 401) {
    print('Token expirado ou inválido');
    // TODO: Redirecionar para login
  }
  return handler.next(error);
}
```

### **Se Backend Retornar 404 (Não Encontrado)**
```dart
_handleError(DioException e) {
  if (e.response?.statusCode == 404) {
    message = 'Não encontrado';
  }
  // ...
}
```

---

## ✅ CHECKLIST: O QUE VOCÊ PRECISA DO BACKEND

- [ ] `POST /api/auth/login` - Retorna token + user
- [ ] `POST /api/auth/register` - Retorna token + user
- [ ] `GET /api/categories?type=movies/series/channels` - Retorna lista de strings
- [ ] `GET /api/items?category={cat}&type={type}&page=1&limit=100` - Retorna array de ContentItem
- [ ] `GET /api/series/details?id={id}` - Retorna SeriesDetails
- [ ] Endpoint de logout (opcional)
- [ ] Endpoint de favoritos (não integrado ainda)
- [ ] Endpoint de perfil (não integrado ainda)

---

## 🎓 CONCLUSÃO

O frontend conecta ao backend de forma:
1. **Simples:** Requisições HTTP diretas
2. **Segura:** Tokens em armazenamento protegido
3. **Robusta:** Com interceptors e tratamento de erro
4. **Real:** Carregando dados do container em 192.168.3.251:4000

**Próximo:** Apenas validar que todos esses endpoints existem e retornam o formato esperado no backend!

---

**Guia Prático Criado:** 15/12/2025  
**Para:** Compreensão do fluxo frontend-backend  
**Status:** Pronto para implementação
