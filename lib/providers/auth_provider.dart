import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config.dart';
import '../core/api/api_client.dart';
import '../core/managed_access_storage.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _apiClient;
  final _secureStorage = const FlutterSecureStorage();
  
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  bool _isLoading = false;
  String? _errorMessage;
  
  AuthProvider(this._apiClient);
  
  // Getters
  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get errorMessage => _errorMessage;
  
  // Inicializar - carregar token salvo
  Future<void> initialize() async {
    try {
      _token = await _secureStorage.read(key: 'auth_token');
      _userId = await _secureStorage.read(key: 'user_id');
      _userName = await _secureStorage.read(key: 'user_name');
      _userEmail = await _secureStorage.read(key: 'user_email');

      if (Config.useManagedAccess && _token != null) {
        final response = await _apiClient.get('/auth/me');
        if (response.statusCode == 200) {
          await _persistManagedDelivery(response.data['delivery']);
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
        _userId = response.data['user']['id'].toString();
        _userName = response.data['user']['name']?.toString();
        _userEmail = response.data['user']['email']?.toString();
        
        // Salvar dados
        await _secureStorage.write(key: 'auth_token', value: _token!);
        await _secureStorage.write(key: 'user_id', value: _userId!);
        await _secureStorage.write(key: 'user_name', value: _userName ?? '');
        await _secureStorage.write(key: 'user_email', value: _userEmail ?? '');
        await _persistManagedDelivery(response.data['delivery']);
        
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
    await _secureStorage.deleteAll();
    await ManagedAccessStorage.clear();
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
}
