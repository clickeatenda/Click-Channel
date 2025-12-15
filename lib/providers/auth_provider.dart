import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/api_client.dart';

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
    } catch (e) {
      print('Erro ao carregar token: $e');
    }
    notifyListeners();
  }
  
  // Login
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
        
        // Salvar dados
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
      
      if (response.statusCode == 201) {
        _token = response.data['token'];
        _userId = response.data['user']['id'].toString();
        _userName = response.data['user']['name'];
        _userEmail = response.data['user']['email'];
        
        await _secureStorage.write(key: 'auth_token', value: _token!);
        await _secureStorage.write(key: 'user_id', value: _userId!);
        await _secureStorage.write(key: 'user_name', value: _userName!);
        await _secureStorage.write(key: 'user_email', value: _userEmail!);
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
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
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}