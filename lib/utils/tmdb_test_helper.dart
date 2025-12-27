import '../data/tmdb_service.dart';
import '../core/utils/logger.dart';

/// Ferramenta para testar e validar buscas no TMDB
class TmdbTestHelper {
  /// Testa uma lista de títulos e mostra os resultados
  static Future<void> testTitles(List<String> titles) async {
    AppLogger.info('🧪 ==========================================');
    AppLogger.info('🧪 INICIANDO TESTE DE ENRIQUECIMENTO TMDB');
    AppLogger.info('🧪 ==========================================');
    
    int successCount = 0;
    int withRatingCount = 0;
    
    for (final title in titles) {
      AppLogger.info('');
      AppLogger.info('🔍 Testando: "$title"');
      AppLogger.info('─'.padRight(60, '─'));
      
      try {
        // Testa busca como filme
        final movieResult = await TmdbService.searchContent(title, type: 'movie');
        if (movieResult != null) {
          AppLogger.info('✅ ENCONTRADO como FILME:');
          AppLogger.info('   Título: ${movieResult.title}');
          AppLogger.info('   Rating: ${movieResult.rating} (${movieResult.rating > 0 ? "TEM RATING" : "SEM RATING"})');
          AppLogger.info('   Popularidade: ${movieResult.popularity}');
          AppLogger.info('   Ano: ${movieResult.releaseDate ?? "N/A"}');
          AppLogger.info('   Gêneros: ${movieResult.genres.join(", ")}');
          AppLogger.info('   Descrição: ${movieResult.overview?.substring(0, movieResult.overview!.length > 100 ? 100 : movieResult.overview!.length)}...');
          successCount++;
          if (movieResult.rating > 0) withRatingCount++;
          continue;
        }
        
        // Se não encontrou como filme, testa como série
        final tvResult = await TmdbService.searchContent(title, type: 'tv');
        if (tvResult != null) {
          AppLogger.info('✅ ENCONTRADO como SÉRIE:');
          AppLogger.info('   Título: ${tvResult.title}');
          AppLogger.info('   Rating: ${tvResult.rating} (${tvResult.rating > 0 ? "TEM RATING" : "SEM RATING"})');
          AppLogger.info('   Popularidade: ${tvResult.popularity}');
          AppLogger.info('   Ano: ${tvResult.releaseDate ?? "N/A"}');
          AppLogger.info('   Gêneros: ${tvResult.genres.join(", ")}');
          successCount++;
          if (tvResult.rating > 0) withRatingCount++;
          continue;
        }
        
        AppLogger.warning('❌ NÃO ENCONTRADO no TMDB');
      } catch (e) {
        AppLogger.error('❌ ERRO ao buscar: $e');
      }
    }
    
    AppLogger.info('');
    AppLogger.info('🧪 ==========================================');
    AppLogger.info('🧪 RESULTADO DO TESTE');
    AppLogger.info('🧪 ==========================================');
    AppLogger.info('Total testado: ${titles.length}');
    AppLogger.info('Encontrados: $successCount (${(successCount / titles.length * 100).toStringAsFixed(1)}%)');
    AppLogger.info('Com rating: $withRatingCount (${successCount > 0 ? (withRatingCount / successCount * 100).toStringAsFixed(1) : 0}%)');
    AppLogger.info('Não encontrados: ${titles.length - successCount}');
  }
  
  /// Lista de títulos problemáticos dos logs para teste
  static List<String> get problematicTitles => [
    'Joe e as Baratas',
    'E.T.: O Extraterrestre',
    'De Volta à Lagoa Azul',
    'A Lagoa Azul',
    'Flashdance: Em Ritmo de Embalo',
    'Free Willy',
    'Esqueceram de Mim 3',
    'Esqueceram de Mim',
    'A Lenda de Ochi',
    'Kaiju No. 8: Missão de Reconhecimento',
    'Os Bad Boas',
    'Back to the Beginning part 2',
    'o Caçador de Tesouros',
    'Fé para o Impossível',
    'O Silêncio da Chuva',
    'Amarelo Manga',
    'Bicho de Sete Cabeças',
  ];
  
  /// Testa títulos problemáticos
  static Future<void> testProblematicTitles() async {
    await testTitles(problematicTitles);
  }
}

