import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class ApiClient {
  // Use Config.backendUrl so the base can be set via .env (e.g. http://host:4000)
  static String get baseUrl => '${Config.backendUrl}/api';
  late final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();
  
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ));
    
    // Interceptor para adicionar token aos headers
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
        onError: (error, handler) {
          // Tratar erro de token expirado
          if (error.response?.statusCode == 401) {
            print('Token expirado ou inválido');
            // TODO: Redirecionar para login
          }
          return handler.next(error);
        },
      ),
    );
    
    // Interceptor para logs
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => print(object),
      ),
    );
  }
  
  // POST request
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
  
  // GET request
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // PUT request
  Future<Response> put(
    String endpoint, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // DELETE request
  Future<Response> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // PATCH request
  Future<Response> patch(
    String endpoint, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Tratamento de erros
  Exception _handleError(DioException e) {
    String message = 'Erro de rede';
    int? statusCode = e.response?.statusCode;
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Tempo de conexão expirado';
        break;
      case DioExceptionType.sendTimeout:
        message = 'Tempo de envio expirado';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Tempo de recebimento expirado';
        break;
      case DioExceptionType.badCertificate:
        message = 'Certificado inválido';
        break;
      case DioExceptionType.badResponse:
        if (statusCode == 400) {
          message = 'Dados inválidos';
        } else if (statusCode == 401) {
          message = 'Não autorizado';
        } else if (statusCode == 403) {
          message = 'Acesso proibido';
        } else if (statusCode == 404) {
          message = 'Não encontrado';
        } else if (statusCode == 500) {
          message = 'Erro do servidor';
        } else {
          message = e.response?.data['message'] ?? 'Erro do servidor';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Requisição cancelada';
        break;
      case DioExceptionType.connectionError:
        message = 'Erro de conexão';
        break;
      case DioExceptionType.unknown:
        message = e.message ?? 'Erro desconhecido';
        break;
    }
    
    return Exception(message);
  }
  
  // Método para fazer upload de arquivos
  Future<Response> uploadFile(
    String endpoint, {
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      
      final response = await _dio.post(endpoint, data: formData);
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Método para fazer download de arquivo
  Future<void> downloadFile({
    required String endpoint,
    required String savePath,
    void Function(int, int)? onReceiveProgress,
  }) async {
    try {
      await _dio.download(
        endpoint,
        savePath,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}