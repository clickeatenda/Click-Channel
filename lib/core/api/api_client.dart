import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../utils/logger.dart';

class ApiClient {
  // Use Config.backendUrl so the base can be set via .env (e.g. http://host:4000)
  static String get baseUrl {
    final url = Config.backendUrl;
    if (url.isEmpty) return 'http://localhost'; // Fallback para evitar erro
    return '$url/api';
  }
  late final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();
  
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),  // Aumentado de 5s para 10s
      receiveTimeout: const Duration(seconds: 10),  // Aumentado de 5s para 10s
      contentType: 'application/json',
      responseType: ResponseType.json,
    ));
    
    // Interceptor para adicionar token aos headers
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final stopwatch = Stopwatch()..start();
          
          try {
            final token = await _secureStorage.read(key: 'auth_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            
            // Log da requisição (sanitizado)
            AppLogger.httpRequest(
              options.method,
              '${options.baseUrl}${options.path}',
            );
          } catch (e) {
            AppLogger.error('Erro ao ler token', error: e);
          }
          
          // Armazenar timestamp para medir duração
          options.extra['start_time'] = stopwatch.elapsedMilliseconds;
          
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Log da resposta (sanitizado)
          final startTime = response.requestOptions.extra['start_time'] as int?;
          final duration = startTime != null 
              ? DateTime.now().millisecondsSinceEpoch - startTime 
              : null;
          
          AppLogger.httpResponse(
            response.statusCode ?? 0,
            response.requestOptions.uri.toString(),
            duration: duration,
          );
          
          return handler.next(response);
        },
        onError: (error, handler) {
          // Tratar erro de token expirado
          if (error.response?.statusCode == 401) {
            AppLogger.warning('Token expirado ou inválido');
            // TODO: Redirecionar para login
          } else {
            AppLogger.error(
              'Erro HTTP: ${error.response?.statusCode}',
              error: error.message,
            );
          }
          return handler.next(error);
        },
      ),
    );
    
    // Interceptor de logs APENAS em debug mode
    // ⚠️ IMPORTANTE: LogInterceptor desabilitado em produção para não expor dados sensíveis
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,  // Desabilitado para não expor dados sensíveis
          responseBody: false,  // Desabilitado para não expor dados sensíveis
          requestHeader: false,  // Desabilitado para não expor tokens
          responseHeader: false,
          error: true,
          logPrint: (object) => AppLogger.debug(object.toString()),
        ),
      );
    }
    
    // ✅ RETRY STRATEGY (Issue #129)
    // Interceptor para retry automático com exponential backoff
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: (message) => AppLogger.debug('Retry: $message'),
        retries: 3,  // Máximo de 3 tentativas
        retryDelays: const [
          Duration(seconds: 1),   // 1ª retry: 1s
          Duration(seconds: 2),   // 2ª retry: 2s
          Duration(seconds: 4),   // 3ª retry: 4s
        ],
        retryableExtraStatuses: {
          408,  // Request Timeout
          429,  // Too Many Requests
          502,  // Bad Gateway
          503,  // Service Unavailable
          504,  // Gateway Timeout
        },
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
        AppLogger.warning('Connection timeout', data: e.requestOptions.uri);
        break;
      case DioExceptionType.sendTimeout:
        message = 'Tempo de envio expirado';
        AppLogger.warning('Send timeout', data: e.requestOptions.uri);
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Tempo de recebimento expirado';
        AppLogger.warning('Receive timeout', data: e.requestOptions.uri);
        break;
      case DioExceptionType.badCertificate:
        message = 'Certificado inválido';
        AppLogger.error('Bad certificate', error: e.message);
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
        AppLogger.error('Bad response: $statusCode', error: message);
        break;
      case DioExceptionType.cancel:
        message = 'Requisição cancelada';
        AppLogger.info('Request cancelled');
        break;
      case DioExceptionType.connectionError:
        message = 'Erro de conexão';
        AppLogger.error('Connection error', error: e.message);
        break;
      case DioExceptionType.unknown:
        message = e.message ?? 'Erro desconhecido';
        AppLogger.error('Unknown error', error: e.message);
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