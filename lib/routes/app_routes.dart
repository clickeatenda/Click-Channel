import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/live_channels_screen.dart';
import '../screens/movies_library_screen.dart';
import '../screens/series_library_screen.dart';
import '../screens/series_detail_screen.dart';
import '../screens/my_favorites_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/player_dashboard_screen.dart';
import '../screens/category_screen.dart';
import '../models/content_item.dart';


class AppRoutes {
  // Route names
  static const String login = '/login';
  static const String home = '/home';
  static const String liveChannels = '/live-channels';
  static const String moviesLibrary = '/movies';
  static const String seriesLibrary = '/series';
  static const String seriesDetail = '/series-detail';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String player = '/player';
  static const String category = '/category';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    try {
      switch (routeSettings.name) {
        case login:
          return MaterialPageRoute(builder: (_) => const LoginScreen());

        case home:
          return MaterialPageRoute(builder: (_) => const HomeScreen());

        case liveChannels:
          return MaterialPageRoute(builder: (_) => const LiveChannelsScreen());

        case moviesLibrary:
          return MaterialPageRoute(builder: (_) => const MoviesLibraryScreen());

        case seriesLibrary:
          return MaterialPageRoute(builder: (_) => const SeriesLibraryScreen());

        case seriesDetail:
  final args = routeSettings.arguments;
  if (args is ContentItem) {
    return MaterialPageRoute(
      builder: (_) => SeriesDetailScreen(item: args),
    );
  }
  return MaterialPageRoute(
    builder: (_) => const Scaffold(
      body: Center(
        child: Text('Item inválido para /series-detail'),
      ),
    ),
  );

        case favorites:
          return MaterialPageRoute(builder: (_) => const MyFavoritesScreen());

        case profile:
          return MaterialPageRoute(builder: (_) => const UserProfileScreen());

        case settings:
          return MaterialPageRoute(builder: (_) => const SettingsScreen());

        case player:
          // por enquanto usa o dashboard genérico de player
          return MaterialPageRoute(
            builder: (_) => const PlayerDashboardScreen(),
          );

        case category:
          // espera receber um Map com categoryName e type em arguments
          final args = routeSettings.arguments;
          String categoryName = 'Ação';
          String type = 'movie';

          if (args is Map) {
            if (args['categoryName'] is String) {
              categoryName = args['categoryName'] as String;
            }
            if (args['type'] is String) {
              type = args['type'] as String;
            }
          }

          return MaterialPageRoute(
            builder: (_) => CategoryScreen(
              categoryName: categoryName,
              type: type,
            ),
          );

        default:
          return MaterialPageRoute(
            builder: (_) => Scaffold(
              body: Center(
                child: Text('Rota não encontrada: ${routeSettings.name}'),
              ),
            ),
          );
      }
    } catch (e) {
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(
            child: Text('Erro ao abrir rota: $e'),
          ),
        ),
      );
    }
  }

  // Navigator helper methods
  static Future<void> goToLogin(BuildContext context) async {
    await Navigator.of(context).pushNamedAndRemoveUntil(
      login,
      (route) => false,
    );
  }

  static Future<void> goToHome(BuildContext context) async {
    await Navigator.of(context).pushNamedAndRemoveUntil(
      home,
      (route) => false,
    );
  }

  static void goToSeriesDetail(BuildContext context, ContentItem item) {
  Navigator.of(context).pushNamed(seriesDetail, arguments: item);
}

  static void goToPlayer(BuildContext context, String contentId) {
    Navigator.of(context).pushNamed(player, arguments: contentId);
  }

  static void goToCategory(
    BuildContext context, {
    required String categoryName,
    required String type,
  }) {
    Navigator.of(context).pushNamed(
      category,
      arguments: {
        'categoryName': categoryName,
        'type': type,
      },
    );
  }

  static void goToLiveChannels(BuildContext context) {
    Navigator.of(context).pushNamed(liveChannels);
  }

  static void goToMovies(BuildContext context) {
    Navigator.of(context).pushNamed(moviesLibrary);
  }

  static void goToSeries(BuildContext context) {
    Navigator.of(context).pushNamed(seriesLibrary);
  }

  static void goToFavorites(BuildContext context) {
    Navigator.of(context).pushNamed(favorites);
  }

  static void goToProfile(BuildContext context) {
    Navigator.of(context).pushNamed(profile);
  }

  static void goToSettings(BuildContext context) {
    Navigator.of(context).pushNamed(settings);
  }

  static void goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
