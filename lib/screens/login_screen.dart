import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedTab = 0;
  bool _obscurePassword = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loginTabFocused = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 17, 19, 24).withOpacity(1),
              const Color.fromARGB(255, 16, 22, 34).withOpacity(1),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background blobs (Otimizados: usando RadialGradient sem BackdropFilter para Fire Stick)
            Positioned(
              top: -200,
              right: -200,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -200,
              left: -200,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryLight.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo and title
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.live_tv, color: Colors.white, size: 28),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Click Channel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.015,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Auth Card
                        GlassPanel(
                          padding: const EdgeInsets.all(0),
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Tabs
                              Row(
                                children: [
                                  Expanded(
                                    child: FocusableActionDetector(
                                      onShowFocusHighlight: (v) => setState(() => _loginTabFocused = v),
                                      actions: {
                                        ActivateIntent: CallbackAction<Intent>(
                                          onInvoke: (_) { setState(() => _selectedTab = 0); return null; },
                                        ),
                                      },
                                      child: GestureDetector(
                                        onTap: () => setState(() => _selectedTab = 0),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: _selectedTab == 0
                                                    ? AppColors.primary
                                                    : _loginTabFocused ? Colors.white : Colors.transparent,
                                                width: _selectedTab == 0 || _loginTabFocused ? 3 : 2,
                                              ),
                                            ),
                                            color: _selectedTab == 0
                                                ? Colors.white.withOpacity(0.05)
                                                : _loginTabFocused ? Colors.white.withOpacity(0.15) : Colors.transparent,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Login',
                                              style: TextStyle(
                                                color: _selectedTab == 0 || _loginTabFocused
                                                    ? Colors.white
                                                    : Colors.white.withOpacity(0.6),
                                                fontSize: 14,
                                                fontWeight: _selectedTab == 0
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedTab = 1),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                                              width: _selectedTab == 1 ? 3 : 2,
                                            ),
                                          ),
                                          color: _selectedTab == 1 ? Colors.white.withOpacity(0.05) : Colors.transparent,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Primeiro acesso',
                                            style: TextStyle(
                                              color: _selectedTab == 1 ? Colors.white : Colors.white.withOpacity(0.6),
                                              fontSize: 14,
                                              fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(
                                color: Colors.white.withOpacity(0.05),
                                height: 0,
                              ),
                              // Tab content
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: _selectedTab == 0 ? _buildLoginForm() : _buildManagedAccessInfo(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Footer
                        Text(
                          'Need help?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final auth = context.watch<AuthProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassInput(
          hintText: 'Usuário liberado pelo administrador',
          controller: _usernameController,
          autofocus: true,
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        GlassInput(
          hintText: 'Senha',
          controller: _passwordController,
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon:
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
          onSuffixTap: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 16),
        if (auth.errorMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Text(
              auth.errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SolidButton(
          label: auth.isLoading ? 'Validando acesso...' : 'Entrar',
          isLoading: auth.isLoading,
          onPressed: _handleLogin,
          width: double.infinity,
        ),
      ],
    );
  }

  void _handleLogin() async {
    final success = await context.read<AuthProvider>().login(
          _usernameController.text,
          _passwordController.text,
        );

    if (!mounted || !success) return;
    Navigator.pushReplacementNamed(context, '/setup');
  }

  Widget _buildManagedAccessInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seu primeiro acesso é liberado pelo time no Click SaaS.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Como funciona:',
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _InfoItem(text: '1. O administrador cria seu usuário no Click SaaS.',
        ),
        const SizedBox(height: 10),
        _InfoItem(text: '2. O conteúdo é liberado manualmente na plataforma parceira.'),
        const SizedBox(height: 10),
        _InfoItem(text: '3. Depois disso, seu acesso já entra com a lista configurada automaticamente.'),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String text;

  const _InfoItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
