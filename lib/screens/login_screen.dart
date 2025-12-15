import 'package:flutter/material.dart';
import 'dart:ui';
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
            // Background blobs
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.withOpacity(0.1),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo and title
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.movie,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'ClickFlix',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.015,
                          ),
                        ),
                        const SizedBox(height: 48),
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
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedTab = 0),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTab == 0
                                                  ? AppColors.primary
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          color: _selectedTab == 0
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.transparent,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Login',
                                            style: TextStyle(
                                              color: _selectedTab == 0
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withOpacity(0.6),
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
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedTab = 1),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTab == 1
                                                  ? AppColors.primary
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          color: _selectedTab == 1
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.transparent,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Register',
                                            style: TextStyle(
                                              color: _selectedTab == 1
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withOpacity(0.6),
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
                                ],
                              ),
                              Divider(
                                color: Colors.white.withOpacity(0.05),
                                height: 0,
                              ),
                              // Tab content
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: _selectedTab == 0
                                    ? _buildLoginForm()
                                    : _buildRegisterForm(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
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
