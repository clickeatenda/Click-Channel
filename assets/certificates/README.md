# 🔒 Certificados SSL - Certificate Pinning

## Propósito

Este diretório armazena os certificados SSL do backend para implementação de **Certificate Pinning**, protegendo contra ataques man-in-the-middle (MITM).

## Como Obter os Certificados

### Opção 1: Usando OpenSSL (Linux/Mac/WSL)

```bash
# Obter certificado do servidor
openssl s_client -connect seu-backend.com:443 -showcerts < /dev/null | \
  openssl x509 -outform PEM > backend_cert.pem

# OU obter toda a cadeia
echo | openssl s_client -servername seu-backend.com -connect seu-backend.com:443 2>/dev/null | \
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > backend_chain.pem
```

### Opção 2: Usando Navegador (Windows/Mac/Linux)

1. Acesse `https://seu-backend.com` no navegador
2. Clique no cadeado na barra de endereço
3. Visualizar certificado
4. Exportar como `.pem` ou `.cer`
5. Salvar neste diretório

### Opção 3: Curl

```bash
curl -v https://seu-backend.com 2>&1 | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > backend_cert.pem
```

## Estrutura de Arquivos

```
assets/certificates/
├── README.md (este arquivo)
├── backend_cert.pem (certificado do backend - adicionar)
├── backend_chain.pem (cadeia completa - opcional)
└── .gitignore (não commitar certificados privados)
```

## Implementação no Código

Após adicionar os certificados, atualizar `lib/core/api/api_client.dart`:

```dart
import 'package:flutter/services.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio(BaseOptions(
      // ... configurações existentes
    ));
    
    // Certificate Pinning
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = 
      (HttpClient client) {
      client.badCertificateCallback = 
        (X509Certificate cert, String host, int port) => false;
      
      // Carregar certificado dos assets
      SecurityContext context = SecurityContext();
      context.setTrustedCertificatesBytes(
        await rootBundle.load('assets/certificates/backend_cert.pem')
          .then((data) => data.buffer.asUint8List())
      );
      
      return HttpClient(context: context);
    };
  }
}
```

**OU usando pacote dio_certificate_pinning:**

```dart
dependencies:
  dio_certificate_pinning: ^2.0.0

// No ApiClient
import 'package:dio_certificate_pinning/dio_certificate_pinning.dart';

ApiClient() {
  _dio.interceptors.add(
    CertificatePinningInterceptor(
      allowedSHAFingerprints: [
        'SHA256_FINGERPRINT_DO_SEU_CERTIFICADO',
      ],
    ),
  );
}
```

## Como Obter SHA256 Fingerprint

```bash
# De um arquivo .pem
openssl x509 -noout -fingerprint -sha256 -inform pem -in backend_cert.pem

# De um servidor online
openssl s_client -connect seu-backend.com:443 < /dev/null 2>/dev/null | \
  openssl x509 -fingerprint -sha256 -noout -in /dev/stdin
```

## Rotação de Certificados

Quando o certificado do backend expirar:

1. Obter novo certificado usando comandos acima
2. Atualizar arquivo `backend_cert.pem`
3. Se usando fingerprints, atualizar lista no código
4. Testar em desenvolvimento
5. Deploy nova versão do app

## ⚠️ IMPORTANTE

- **NÃO** commitar certificados privados (`.key`, `.p12`)
- **SIM** commitar certificados públicos (`.pem`, `.cer`)
- Documentar data de expiração dos certificados
- Configurar alertas para expiração (90 dias antes)

## Segurança

Certificate Pinning protege contra:
- ✅ Ataques man-in-the-middle (MITM)
- ✅ Certificados fraudulentos de CAs comprometidas
- ✅ Proxy maliciosos

Mas requer:
- ⚠️ Gerenciamento cuidadoso de rotação
- ⚠️ Fallback para casos de emergência
- ⚠️ Testes rigorosos antes de deploy

## Status

- [ ] Certificados obtidos
- [ ] Certificate pinning implementado
- [ ] Testado em desenvolvimento
- [ ] Testado em produção
- [ ] Alertas de expiração configurados

## Links Úteis

- [OWASP Certificate Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- [Dio Certificate Pinning Package](https://pub.dev/packages/dio_certificate_pinning)
- [OpenSSL Documentation](https://www.openssl.org/docs/)

---

**Última atualização:** 23/12/2025
**Responsável:** [A definir]
**Issue GitHub:** #130

