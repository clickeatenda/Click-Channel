import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../data/favorites_service.dart';
import '../data/watch_history_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_panel.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Future<int> _watchedCountFuture = WatchHistoryService.getWatchedHistory().then((items) => items.length);

  Future<void> _refreshCounts() async {
    setState(() {
      _watchedCountFuture = WatchHistoryService.getWatchedHistory().then((items) => items.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 11),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassPanel(
                      child: Column(
                        children: [
                          const Text(
                            'Perfil do Usuário',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 3,
                              ),
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                            child: Center(
                              child: Text(
                                _buildInitials(auth.userName, auth.username),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            auth.userName?.isNotEmpty == true ? auth.userName! : 'Usuário Click Channel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.username?.isNotEmpty == true ? '@${auth.username}' : 'Acesso gerenciado',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (auth.userEmail?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              auth.userEmail!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: GlassButton(
                                  label: 'Meus Favoritos',
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/favorites').then((_) => _refreshCounts());
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassButton(
                                  label: 'Configurações',
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/settings');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Preferências',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<List<dynamic>>(
                      valueListenable: FavoritesService.favoritesNotifier,
                      builder: (context, favorites, _) {
                        return FutureBuilder<int>(
                          future: _watchedCountFuture,
                          builder: (context, snapshot) {
                            final watchedCount = snapshot.data ?? 0;
                            return GridView.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildStatCard('${favorites.length}', 'Favoritos'),
                                _buildStatCard('$watchedCount', 'Últimos vistos'),
                                _buildStatCard(
                                  _formatSubscriptionState(auth.accessStatus),
                                  'Status',
                                  isTextValue: true,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Assinatura',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.planName?.isNotEmpty == true ? auth.planName! : 'Plano não informado',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _buildSubscriptionSummary(
                                        signedAt: auth.signedAt,
                                        expiresAt: auth.expiresAt,
                                      ),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusChip(status: auth.accessStatus),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildInfoBlock(
                                'Data da assinatura',
                                _formatDate(auth.signedAt) ?? 'Não informada',
                              ),
                              _buildInfoBlock(
                                'Vencimento',
                                _formatDate(auth.expiresAt) ?? 'Não informado',
                              ),
                              _buildInfoBlock(
                                'Usuário',
                                auth.username?.isNotEmpty == true ? auth.username! : 'Não informado',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, {bool isTextValue = false}) {
    return GlassPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTextValue ? 18 : 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _buildInitials(String? name, String? username) {
    final source = (name?.trim().isNotEmpty == true ? name!.trim() : username?.trim() ?? 'CC')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    return source.isEmpty ? 'CC' : source;
  }

  String _buildSubscriptionSummary({String? signedAt, String? expiresAt}) {
    final signed = _formatDate(signedAt);
    final expires = _formatDate(expiresAt);

    if (signed != null && expires != null) {
      return 'Assinado em $signed • vence em $expires';
    }
    if (expires != null) {
      return 'Vencimento em $expires';
    }
    if (signed != null) {
      return 'Assinado em $signed';
    }
    return 'Sem datas informadas';
  }

  String _formatSubscriptionState(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'active':
        return 'Ativo';
      case 'blocked':
        return 'Bloqueado';
      case 'inactive':
        return 'Pendente';
      case 'expired':
        return 'Expirado';
      default:
        return 'Indefinido';
    }
  }

  String? _formatDate(String? value) {
    if (value == null || value.isEmpty) return null;

    final date = DateTime.tryParse(value);
    if (date == null) return value;

    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = (status ?? '').toLowerCase();
    final color = switch (normalized) {
      'active' => AppColors.success,
      'blocked' => AppColors.error,
      'expired' => Colors.orange,
      _ => Colors.white70,
    };

    final label = switch (normalized) {
      'active' => 'Ativo',
      'blocked' => 'Bloqueado',
      'inactive' => 'Pendente',
      'expired' => 'Expirado',
      _ => 'Indefinido',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(
          color: color,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
