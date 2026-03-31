import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedTab = 0;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loginTabFocused = false;
  bool _registerTabFocused = false;
  bool _forgotPasswordFocused = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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
                                    child: FocusableActionDetector(
                                      onShowFocusHighlight: (v) => setState(() => _registerTabFocused = v),
                                      actions: {
                                        ActivateIntent: CallbackAction<Intent>(
                                          onInvoke: (_) { setState(() => _selectedTab = 1); return null; },
                                        ),
                                      },
                                      child: GestureDetector(
                                        onTap: () => setState(() => _selectedTab = 1),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: _selectedTab == 1
                                                    ? AppColors.primary
                                                    : _registerTabFocused ? Colors.white : Colors.transparent,
                                                width: _selectedTab == 1 || _registerTabFocused ? 3 : 2,
                                              ),
                                            ),
                                            color: _selectedTab == 1
                                                ? Colors.white.withOpacity(0.05)
                                                : _registerTabFocused ? Colors.white.withOpacity(0.15) : Colors.transparent,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Register',
                                              style: TextStyle(
                                                color: _selectedTab == 1 || _registerTabFocused
                                                    ? Colors.white
                                                    : Colors.white.withOpacity(0.6),
                                                fontSize: 14,
                                                fontWeight: _selectedTab == 1
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
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
                                child: _selectedTab == 0
                                    ? _buildLoginForm()
                                    : _buildRegisterForm(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassInput(
          hintText: 'Email',
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline,
        ),
        const SizedBox(height: 12),
        GlassInput(
          hintText: 'Password',
          controller: _passwordController,
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon:
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
          onSuffixTap: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FocusableActionDetector(
            onShowFocusHighlight: (v) => setState(() => _forgotPasswordFocused = v),
            actions: {
              ActivateIntent: CallbackAction<Intent>(
                onInvoke: (_) { /* handle forgot password */ return null; },
              ),
            },
            child: GestureDetector(
              onTap: () {},
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _forgotPasswordFocused ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Login sempre libera acesso
        SolidButton(
          label: 'Sign In',
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
          width: double.infinity,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GlassButton(
                label: '',
                onPressed: () {},
                icon: Icons.g_mobiledata,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassButton(
                label: '',
                onPressed: () {},
                icon: Icons.apple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassButton(
                label: '',
                onPressed: () {},
                icon: Icons.language,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassInput(
          hintText: 'Full Name',
          controller: _nameController,
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        GlassInput(
          hintText: 'Email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline,
        ),
        const SizedBox(height: 16),
        GlassInput(
          hintText: 'Password',
          controller: _passwordController,
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon:
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
          onSuffixTap: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 24),
        // Registro também entra direto
        SolidButton(
          label: 'Create Account',
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
          width: double.infinity,
        ),
      ],
    );
  }
}
