import 'package:flutter/foundation.dart';

/// Sistema de logging estruturado com níveis e sanitização
/// 
/// Uso:
/// ```dart
/// AppLogger.debug('Mensagem de debug');
/// AppLogger.info('Informação geral');
/// AppLogger.warning('Aviso');
/// AppLogger.error('Erro', error: exception);
/// ```
class AppLogger {
  // Configuração de ambiente
  static bool get _isProduction => kReleaseMode;
  static bool get _isDebug => kDebugMode;

  /// Log de debug - apenas em modo debug
  static void debug(String message, {Object? data}) {
    if (_isDebug) {
      print('🐛 [DEBUG] $message');
      if (data != null) {
        print('   Data: ${_sanitize(data.toString())}');
      }
    }
  }

  /// Log de informação - aparece em todos os ambientes
  static void info(String message, {Object? data}) {
    if (_isDebug || !_isProduction) {
      print('ℹ️  [INFO] $message');
      if (data != null) {
        print('   Data: ${_sanitize(data.toString())}');
      }
    }
  }

  /// Log de aviso - aparece em todos os ambientes
  static void warning(String message, {Object? data}) {
    print('⚠️  [WARNING] $message');
    if (data != null && _isDebug) {
      print('   Data: ${_sanitize(data.toString())}');
    }
  }

  /// Log de erro - sempre aparece, com stack trace opcional
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    print('❌ [ERROR] $message');
    if (error != null) {
      print('   Error: ${_sanitize(error.toString())}');
    }
    if (stackTrace != null && _isDebug) {
      print('   StackTrace: $stackTrace');
    }
  }

  /// Log de sucesso - apenas em modo debug
  static void success(String message) {
    if (_isDebug) {
      print('✅ [SUCCESS] $message');
    }
  }

  /// Log de requisição HTTP - sanitizado
  static void httpRequest(String method, String url) {
    if (_isDebug) {
      print('🌐 [HTTP] $method ${_sanitizeUrl(url)}');
    }
  }

  /// Log de resposta HTTP - sanitizado
  static void httpResponse(int statusCode, String url, {int? duration}) {
    if (_isDebug) {
      final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
      final durationText = duration != null ? ' (${duration}ms)' : '';
      print('$emoji [HTTP] $statusCode ${_sanitizeUrl(url)}$durationText');
    }
  }

  /// Sanitização de dados sensíveis
  static String _sanitize(String data) {
    String sanitized = data;

    // Remover tokens Bearer
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'Bearer\s+[^\s]+', caseSensitive: false),
      (match) => 'Bearer ***REDACTED***',
    );

    // Remover tokens genéricos
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'"token"\s*:\s*"[^"]+"', caseSensitive: false),
      (match) => '"token": "***REDACTED***"',
    );

    // Remover senhas
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'"password"\s*:\s*"[^"]+"', caseSensitive: false),
      (match) => '"password": "***REDACTED***"',
    );

    // Remover API keys
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'"api_key"\s*:\s*"[^"]+"', caseSensitive: false),
      (match) => '"api_key": "***REDACTED***"',
    );

    // Remover Authorization headers
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'"authorization"\s*:\s*"[^"]+"', caseSensitive: false),
      (match) => '"authorization": "***REDACTED***"',
    );

    return sanitized;
  }

  /// Sanitização de URLs (remover query params sensíveis)
  static String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Se tem query parameters sensíveis, sanitizar
      if (uri.hasQuery) {
        final sanitizedParams = <String, String>{};
        uri.queryParameters.forEach((key, value) {
          // Lista de parâmetros sensíveis
          final sensitiveParams = [
            'token',
            'password',
            'api_key',
            'apikey',
            'secret',
            'auth',
            'key',
          ];
          
          if (sensitiveParams.any((p) => key.toLowerCase().contains(p))) {
            sanitizedParams[key] = '***REDACTED***';
          } else {
            sanitizedParams[key] = value;
          }
        });
        
        return uri.replace(queryParameters: sanitizedParams).toString();
      }
      
      return url;
    } catch (e) {
      // Se falhar ao parsear, retornar URL original
      return url;
    }
  }

  /// Log de performance
  static void performance(String operation, Duration duration) {
    if (_isDebug) {
      final ms = duration.inMilliseconds;
      final emoji = ms < 100 ? '⚡' : ms < 500 ? '🐢' : '🐌';
      print('$emoji [PERF] $operation: ${ms}ms');
    }
  }

  /// Limpar console (apenas debug)
  static void clear() {
    if (_isDebug) {
      print('\n' * 50);
    }
  }

  /// Separador visual
  static void separator([String? title]) {
    if (_isDebug) {
      if (title != null) {
        const separatorLine = '============================================================';
        print('\n$separatorLine');
        print('  $title');
        print('$separatorLine\n');
      } else {
        const separatorLine = '────────────────────────────────────────────────────────────';
        print(separatorLine);
      }
    }
  }
}

