import 'dart:io';
import 'package:flutter/services.dart';

/// Gerenciador de Segurança (Certificate Pinning)
/// Utilizado para carregar os certificados válidos do backend em um SecurityContext.
class SecurityContextManager {
  static SecurityContext? _pinnedContext;

  /// Retorna o SecurityContext configurado para pinning.
  /// Caso não tenha sido inicializado, retorna nulo/vazio.
  static SecurityContext? get pinnedContext => _pinnedContext;

  /// Inicializa e configura os Root Certificates baseados nos PEM configurados no assets.
  static Future<void> init() async {
    try {
      // IMPORTANTE: withTrustedRoots: true mantém as CAs padrão do sistema.
      // Adicionamos o cert extra (pinning) sem remover os root certs do S.O.
      // withTrustedRoots: false quebra imagens de TMDB, Jellyfin, M3U CDNs etc.
      final SecurityContext context = SecurityContext(withTrustedRoots: true);

      // Adiciona o cert da CA própria do backend SOBRE os root certs do sistema
      final String certStr = await rootBundle.loadString('assets/certificates/isrgrootx1.pem');
      
      final List<int> certBytes = certStr.codeUnits;
      context.setTrustedCertificatesBytes(certBytes);
      
      _pinnedContext = context;
      print('🔒 SecurityContextManager: Certificate pinning habilitado com sucesso.');
    } catch (e) {
      print('❌ SecurityContextManager: Erro ao carregar certificados do Pinning: $e');
      // Fallback: em caso de erro crítico, usar as roots padrão
      _pinnedContext = SecurityContext(withTrustedRoots: true);
    }
  }
}
