import 'dart:io';

/// Permite aceitar certificados SSL inválidos/auto-assinados (comum em servidores de IPTV)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
