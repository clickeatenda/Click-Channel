import 'package:shared_preferences/shared_preferences.dart';

/// Serviço genérico para gerenciar histórico das buscas por texto
class SearchHistoryService {
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 10;
  static SharedPreferences? _prefs;

  static Future<void> _ensureInit() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Recupera as últimas strings pesquisadas
  static Future<List<String>> getSearchHistory() async {
    await _ensureInit();
    final data = _prefs!.getStringList(_historyKey);
    return data ?? [];
  }

  /// Adiciona uma query ao histórico
  static Future<void> addQuery(String query) async {
    if (query.trim().length < 2) return;
    
    await _ensureInit();
    final history = await getSearchHistory();
    
    // Remove if exists to put it at the beginning
    history.removeWhere((q) => q.toLowerCase() == query.toLowerCase());
    
    history.insert(0, query.trim());
    
    // Limit Max
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    await _prefs!.setStringList(_historyKey, history);
  }

  /// Remove uma exata query
  static Future<void> removeQuery(String query) async {
    await _ensureInit();
    final history = await getSearchHistory();
    history.removeWhere((q) => q.toLowerCase() == query.toLowerCase());
    await _prefs!.setStringList(_historyKey, history);
  }

  /// Limpa tudo
  static Future<void> clearHistory() async {
    await _ensureInit();
    await _prefs!.remove(_historyKey);
  }
}
