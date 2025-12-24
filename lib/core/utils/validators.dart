/// Sistema de validação e sanitização de inputs
/// 
/// Uso:
/// ```dart
/// if (!Validators.isValidUrl(url)) {
///   print('URL inválida');
/// }
/// 
/// final sanitized = Validators.sanitizeInput(userInput);
/// ```
class Validators {
  // Lista de protocolos permitidos
  static const _allowedProtocols = ['http', 'https', 'file'];
  
  // Regex para email
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  // Regex para URL
  static final _urlRegex = RegExp(
    r'^(https?|file):\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  /// Valida se uma URL é válida e segura
  /// 
  /// Verifica:
  /// - Formato válido de URL
  /// - Protocolo permitido (http, https, file)
  /// - Tamanho razoável
  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return false;
    }

    // Verificar tamanho máximo (proteção contra DoS)
    if (url.length > 2048) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      
      // Verificar se tem esquema (protocolo)
      if (uri.scheme.isEmpty) {
        return false;
      }
      
      // Verificar se o protocolo é permitido
      if (!_allowedProtocols.contains(uri.scheme.toLowerCase())) {
        return false;
      }
      
      // Para http/https, verificar se tem host
      if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Valida URL de playlist M3U
  static bool isValidM3UUrl(String? url) {
    if (!isValidUrl(url)) {
      return false;
    }
    
    // Aceitar URLs que terminam com .m3u ou .m3u8, ou que contém playlist
    final lowerUrl = url!.toLowerCase();
    return lowerUrl.endsWith('.m3u') ||
           lowerUrl.endsWith('.m3u8') ||
           lowerUrl.contains('playlist') ||
           lowerUrl.contains('get.php'); // Formato comum de APIs IPTV
  }

  /// Valida URL de EPG (XMLTV)
  static bool isValidEpgUrl(String? url) {
    if (!isValidUrl(url)) {
      return false;
    }
    
    // Aceitar URLs XML ou XMLTV
    final lowerUrl = url!.toLowerCase();
    return lowerUrl.endsWith('.xml') ||
           lowerUrl.endsWith('.xmltv') ||
           lowerUrl.contains('epg') ||
           lowerUrl.contains('xmltv');
  }

  /// Valida formato de email
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return false;
    }
    
    // Verificar tamanho razoável
    if (email.length > 320) {  // RFC 5321
      return false;
    }
    
    return _emailRegex.hasMatch(email.trim());
  }

  /// Valida senha com requisitos mínimos
  /// 
  /// Requisitos:
  /// - Mínimo 6 caracteres
  /// - Máximo 128 caracteres
  static bool isValidPassword(String? password) {
    if (password == null || password.isEmpty) {
      return false;
    }
    
    return password.length >= 6 && password.length <= 128;
  }

  /// Valida senha forte (opcional para registro)
  /// 
  /// Requisitos:
  /// - Mínimo 8 caracteres
  /// - Pelo menos uma letra maiúscula
  /// - Pelo menos uma letra minúscula
  /// - Pelo menos um número
  static bool isStrongPassword(String? password) {
    if (password == null || password.isEmpty) {
      return false;
    }
    
    if (password.length < 8) {
      return false;
    }
    
    // Verificar se tem letra maiúscula
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return false;
    }
    
    // Verificar se tem letra minúscula
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return false;
    }
    
    // Verificar se tem número
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return false;
    }
    
    return true;
  }

  /// Sanitiza input genérico removendo caracteres perigosos
  /// 
  /// Remove:
  /// - Tags HTML
  /// - Caracteres de controle
  /// - Null bytes
  static String sanitizeInput(String? input) {
    if (input == null || input.isEmpty) {
      return '';
    }
    
    String sanitized = input;
    
    // Remover tags HTML
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Remover null bytes
    sanitized = sanitized.replaceAll('\u0000', '');
    
    // Remover caracteres de controle (exceto tabs, newlines)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
    
    // Trim
    sanitized = sanitized.trim();
    
    return sanitized;
  }

  /// Sanitiza URL removendo espaços e caracteres inválidos
  static String sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    
    // Remover espaços
    String sanitized = url.trim().replaceAll(' ', '');
    
    // Remover caracteres de controle
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    return sanitized;
  }

  /// Valida nome de usuário
  /// 
  /// Permite:
  /// - Letras (a-z, A-Z)
  /// - Números (0-9)
  /// - Underscores (_)
  /// - Hífens (-)
  /// - Pontos (.)
  static bool isValidUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return false;
    }
    
    // Tamanho entre 3 e 30 caracteres
    if (username.length < 3 || username.length > 30) {
      return false;
    }
    
    // Apenas caracteres permitidos
    return RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username);
  }

  /// Valida número de telefone (formato brasileiro)
  static bool isValidPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return false;
    }
    
    // Remover caracteres não numéricos
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Deve ter 10 ou 11 dígitos (DDD + número)
    return digits.length == 10 || digits.length == 11;
  }

  /// Valida tamanho de arquivo (em bytes)
  /// 
  /// Exemplo: validar upload de imagem até 5MB
  static bool isValidFileSize(int size, {int maxSizeInMB = 5}) {
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    return size > 0 && size <= maxSizeInBytes;
  }

  /// Valida extensão de arquivo
  static bool isValidFileExtension(String filename, List<String> allowedExtensions) {
    if (filename.isEmpty) {
      return false;
    }
    
    final extension = filename.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }

  /// Valida se string contém apenas caracteres alfanuméricos
  static bool isAlphanumeric(String? text) {
    if (text == null || text.isEmpty) {
      return false;
    }
    
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
  }

  /// Valida se string é numérica
  static bool isNumeric(String? text) {
    if (text == null || text.isEmpty) {
      return false;
    }
    
    return RegExp(r'^[0-9]+$').hasMatch(text);
  }

  /// Valida CPF (formato brasileiro)
  static bool isValidCPF(String? cpf) {
    if (cpf == null || cpf.isEmpty) {
      return false;
    }
    
    // Remover caracteres não numéricos
    final digits = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Deve ter 11 dígitos
    if (digits.length != 11) {
      return false;
    }
    
    // Verificar se não são todos iguais (ex: 111.111.111-11)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
      return false;
    }
    
    // Validar dígitos verificadores
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(digits[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;
    
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(digits[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;
    
    return digits[9] == digit1.toString() && digits[10] == digit2.toString();
  }

  /// Mensagem de erro formatada para URL
  static String getUrlErrorMessage(String? url) {
    if (url == null || url.trim().isEmpty) {
      return 'URL não pode estar vazia';
    }
    
    if (url.length > 2048) {
      return 'URL muito longa (máximo 2048 caracteres)';
    }
    
    try {
      final uri = Uri.parse(url);
      
      if (uri.scheme.isEmpty) {
        return 'URL deve começar com http://, https:// ou file://';
      }
      
      if (!_allowedProtocols.contains(uri.scheme.toLowerCase())) {
        return 'Protocolo não permitido. Use http://, https:// ou file://';
      }
      
      if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
        return 'URL inválida: host não especificado';
      }
    } catch (e) {
      return 'URL inválida: formato incorreto';
    }
    
    return 'URL inválida';
  }

  /// Mensagem de erro formatada para email
  static String getEmailErrorMessage(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email não pode estar vazio';
    }
    
    if (email.length > 320) {
      return 'Email muito longo (máximo 320 caracteres)';
    }
    
    if (!_emailRegex.hasMatch(email.trim())) {
      return 'Formato de email inválido';
    }
    
    return 'Email inválido';
  }

  /// Mensagem de erro formatada para senha
  static String getPasswordErrorMessage(String? password, {bool requireStrong = false}) {
    if (password == null || password.isEmpty) {
      return 'Senha não pode estar vazia';
    }
    
    if (requireStrong) {
      if (password.length < 8) {
        return 'Senha deve ter no mínimo 8 caracteres';
      }
      
      if (!RegExp(r'[A-Z]').hasMatch(password)) {
        return 'Senha deve conter pelo menos uma letra maiúscula';
      }
      
      if (!RegExp(r'[a-z]').hasMatch(password)) {
        return 'Senha deve conter pelo menos uma letra minúscula';
      }
      
      if (!RegExp(r'[0-9]').hasMatch(password)) {
        return 'Senha deve conter pelo menos um número';
      }
    } else {
      if (password.length < 6) {
        return 'Senha deve ter no mínimo 6 caracteres';
      }
      
      if (password.length > 128) {
        return 'Senha muito longa (máximo 128 caracteres)';
      }
    }
    
    return 'Senha inválida';
  }
}

