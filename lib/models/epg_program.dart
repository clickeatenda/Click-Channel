/// Modelo para um programa do EPG
class EpgProgram {
  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? category;
  final String? icon;
  final String? rating;
  final String? episodeNum;

  EpgProgram({
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.category,
    this.icon,
    this.rating,
    this.episodeNum,
  });

  /// Verifica se o programa está ao vivo agora
  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Verifica se o programa já terminou
  bool get hasEnded => DateTime.now().isAfter(end);

  /// Verifica se o programa ainda não começou
  bool get isUpcoming => DateTime.now().isBefore(start);

  /// Retorna a duração em minutos
  int get durationMinutes => end.difference(start).inMinutes;

  /// Retorna o progresso atual (0.0 a 1.0) se estiver ao vivo
  double get progress {
    if (!isLive) return hasEnded ? 1.0 : 0.0;
    final total = end.difference(start).inSeconds;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Tempo restante em minutos (se ao vivo)
  int get remainingMinutes {
    if (!isLive) return 0;
    return end.difference(DateTime.now()).inMinutes;
  }

  /// Formata horário de início
  String get startTimeFormatted {
    return '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  }

  /// Formata horário de fim
  String get endTimeFormatted {
    return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }

  /// Status do programa
  String get statusLabel {
    if (isLive) return 'AO VIVO';
    if (isUpcoming) {
      final diff = start.difference(DateTime.now());
      if (diff.inMinutes < 60) {
        return 'Em ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'Em ${diff.inHours}h';
      }
      return 'Em breve';
    }
    return 'Encerrado';
  }

  @override
  String toString() => 'EpgProgram($title, $startTimeFormatted-$endTimeFormatted)';
}

/// Informações de EPG de um canal
class EpgChannel {
  final String id;
  final String displayName;
  final String? icon;
  final List<EpgProgram> programs;

  EpgChannel({
    required this.id,
    required this.displayName,
    this.icon,
    this.programs = const [],
  });

  /// Programa atual (ao vivo)
  EpgProgram? get currentProgram {
    try {
      return programs.firstWhere((p) => p.isLive);
    } catch (_) {
      return null;
    }
  }

  /// Próximo programa
  EpgProgram? get nextProgram {
    final now = DateTime.now();
    try {
      return programs.where((p) => p.start.isAfter(now)).reduce(
        (a, b) => a.start.isBefore(b.start) ? a : b,
      );
    } catch (_) {
      return null;
    }
  }

  /// Programas de hoje
  List<EpgProgram> get todayPrograms {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return programs.where((p) => 
      p.start.isAfter(today) && p.start.isBefore(tomorrow)
    ).toList()..sort((a, b) => a.start.compareTo(b.start));
  }
}
