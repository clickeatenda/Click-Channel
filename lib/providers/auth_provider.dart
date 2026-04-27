import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config.dart';
import '../core/api/api_client.dart';
import '../core/managed_access_storage.dart';
import '../data/favorites_service.dart';
import '../data/watch_history_service.dart';
import '../data/managed_user_preferences_api.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient;
  final _secureStorage = const FlutterSecureStorage();
  
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _username;
  String? _planName;
  String? _signedAt;
  String? _expiresAt;
  String? _accessStatus;
  bool _isLoading = false;
  String? _errorMessage;
  
  AuthProvider(this._apiClient);
  
  // Getters
  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get username => _username;
  String? get planName => _planName;
  String? get signedAt => _signedAt;
  String? get expiresAt => _expiresAt;
  String? get accessStatus => _accessStatus;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get errorMessage => _errorMessage;
  
  // Inicializar - carregar token salvo
  Future<void> initialize() async {
    try {
      _token = await _secureStorage.read(key: 'auth_token');
      await _loadCachedIdentity();
      await FavoritesService.setUserScope(_userId);
      await WatchHistoryService.setUserScope(_userId);

      if (Config.useManagedAccess && _token != null) {
        final response = await _apiClient.get('/auth/me');
        if (response.statusCode == 200) {
          _applySessionUser(response.data['user']);
          await FavoritesService.setUserScope(_userId);
          await WatchHistoryService.setUserScope(_userId);
          await _persistManagedDelivery(response.data['delivery']);
          await _persistIdentityCache();
          await _hydrateManagedPreferences();
        }
      }
    } catch (e) {
      print('Erro ao carregar token: $e');
      await logout();
    }
    notifyListeners();
  }
  
  // Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      
      if (response.statusCode == 200) {
        _token = response.data['token'];
        _applySessionUser(response.data['user']);
        
        // Salvar dados
        await _secureStorage.write(key: 'auth_token', value: _token!);
        await _persistIdentityCache();
        await FavoritesService.setUserScope(_userId);
        await WatchHistoryService.setUserScope(_userId);
        await _persistManagedDelivery(response.data['delivery']);
        await _hydrateManagedPreferences();
        
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
  
  // Register
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );
      
      _errorMessage = response.data['error']?.toString() ??
          'O cadastro é feito pelo administrador do Click SaaS.';
    } catch (e) {
      _errorMessage = 'Erro ao registrar: ${e.toString()}';
      print('Register error: $e');
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  // Logout
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _username = null;
    _planName = null;
    _signedAt = null;
    _expiresAt = null;
    _accessStatus = null;
    await _secureStorage.deleteAll();
    await ManagedAccessStorage.clear();
    await FavoritesService.setUserScope(null);
    await WatchHistoryService.setUserScope(null);
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _persistManagedDelivery(dynamic delivery) async {
    if (delivery is! Map) return;

    final mode = delivery['mode']?.toString();
    final url = delivery['url']?.toString();

    if (mode == null || url == null || url.isEmpty) return;

    await ManagedAccessStorage.save(
      mode: mode,
      url: url,
      username: delivery['username']?.toString(),
      password: delivery['password']?.toString(),
      providerLabel: delivery['providerLabel']?.toString(),
    );
  }

  Future<void> _loadCachedIdentity() async {
    _userId = await _secureStorage.read(key: 'user_id');
    _userName = await _secureStorage.read(key: 'user_name');
    _userEmail = await _secureStorage.read(key: 'user_email');
    _username = await _secureStorage.read(key: 'username');
    _planName = await _secureStorage.read(key: 'plan_name');
    _signedAt = await _secureStorage.read(key: 'signed_at');
    _expiresAt = await _secureStorage.read(key: 'expires_at');
    _accessStatus = await _secureStorage.read(key: 'access_status');
  }

  Future<void> _persistIdentityCache() async {
    if (_userId != null) {
      await _secureStorage.write(key: 'user_id', value: _userId!);
    }
    await _secureStorage.write(key: 'user_name', value: _userName ?? '');
    await _secureStorage.write(key: 'user_email', value: _userEmail ?? '');
    await _secureStorage.write(key: 'username', value: _username ?? '');
    await _secureStorage.write(key: 'plan_name', value: _planName ?? '');
    await _secureStorage.write(key: 'signed_at', value: _signedAt ?? '');
    await _secureStorage.write(key: 'expires_at', value: _expiresAt ?? '');
    await _secureStorage.write(key: 'access_status', value: _accessStatus ?? '');
  }

  void _applySessionUser(dynamic user) {
    if (user is! Map) return;

    _userId = user['id']?.toString();
    _userName = user['name']?.toString();
    _userEmail = user['email']?.toString();
    _username = user['username']?.toString();
    _planName = user['planName']?.toString();
    _signedAt = user['signedAt']?.toString();
    _expiresAt = user['expiresAt']?.toString();
    _accessStatus = user['accessStatus']?.toString();
  }

  Future<void> _hydrateManagedPreferences() async {
    final preferences = await ManagedUserPreferencesApi.fetchPreferences();
    if (preferences == null) return;

    final favorites = preferences['favorites'];
    if (favorites is List) {
      await FavoritesService.hydrateFromPreferencePayload(favorites);
    }

    final watchedHistory = preferences['watchedHistory'];
    if (watchedHistory is List) {
      await WatchHistoryService.hydrateWatchedHistoryFromPreferencePayload(watchedHistory);
    }
  }
}
