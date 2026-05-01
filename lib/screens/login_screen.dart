import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/blinking_cursor_placeholder.dart';
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
  final _usernameFocusNode = FocusNode(debugLabel: 'login_username');
  final _passwordFocusNode = FocusNode(debugLabel: 'login_password');
  final _submitFocusNode = FocusNode(debugLabel: 'login_submit');
  final _usernameEditFocusNode = FocusNode(debugLabel: 'login_username_edit');
  final _passwordEditFocusNode = FocusNode(debugLabel: 'login_password_edit');

  bool _loginTabFocused = false;
  bool _usernameActive = false;
  bool _passwordActive = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleRemoteKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _usernameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleRemoteKey);
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _submitFocusNode.dispose();
    _usernameEditFocusNode.dispose();
    _passwordEditFocusNode.dispose();
    super.dispose();
  }

  bool _handleRemoteKey(KeyEvent event) {
    if (event is! KeyDownEvent || _selectedTab != 0) return false;

    final key = event.logicalKey;
    final primaryFocus = FocusManager.instance.primaryFocus;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (primaryFocus == _usernameFocusNode || primaryFocus == _usernameEditFocusNode) {
        if (_usernameActive) {
          setState(() => _usernameActive = false);
        }
        _passwordFocusNode.requestFocus();
        return true;
      }
      if (primaryFocus == _passwordFocusNode || primaryFocus == _passwordEditFocusNode) {
        if (_passwordActive) {
          setState(() => _passwordActive = false);
        }
        _submitFocusNode.requestFocus();
        return true;
      }
      return false;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (primaryFocus == _submitFocusNode) {
        _passwordFocusNode.requestFocus();
        return true;
      }
      if (primaryFocus == _passwordFocusNode || primaryFocus == _passwordEditFocusNode) {
        if (_passwordActive) {
          setState(() => _passwordActive = false);
        }
        _usernameFocusNode.requestFocus();
        return true;
      }
      return false;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_usernameActive) {
        setState(() => _usernameActive = false);
        _usernameFocusNode.requestFocus();
        return true;
      }
      if (_passwordActive) {
        setState(() => _passwordActive = false);
        _passwordFocusNode.requestFocus();
        return true;
      }
    }

    final isActivate = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA;

    if (isActivate && primaryFocus == _usernameFocusNode) {
      _activateUsernameField();
      return true;
    }

    if (isActivate && primaryFocus == _passwordFocusNode) {
      _activatePasswordField();
      return true;
    }

    if (isActivate && primaryFocus == _submitFocusNode) {
      final auth = context.read<AuthProvider>();
      if (!auth.isLoading) _handleLogin();
      return true;
    }

    return false;
  }

  void _activateUsernameField() {
    _activateRemoteTextField(
      setActive: () => setState(() => _usernameActive = true),
      editFocusNode: _usernameEditFocusNode,
    );
  }

  void _activatePasswordField() {
    _activateRemoteTextField(
      setActive: () => setState(() => _passwordActive = true),
      editFocusNode: _passwordEditFocusNode,
    );
  }

  void _activateRemoteTextField({
    required VoidCallback setActive,
    required FocusNode editFocusNode,
  }) {
    setActive();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      editFocusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');

      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && editFocusNode.hasFocus) {
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    });
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
                        const _OfficialAppMark(),
                        const SizedBox(height: 20),
                        const Text(
                          'Click Channel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.015,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Entre com sua conta oficial do aplicativo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
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
        _buildRemoteTextField(
          hintText: 'Usuário liberado pelo administrador',
          controller: _usernameController,
          placeholderFocusNode: _usernameFocusNode,
          editFocusNode: _usernameEditFocusNode,
          active: _usernameActive,
          onActivateField: _activateUsernameField,
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            setState(() => _usernameActive = false);
            _passwordFocusNode.requestFocus();
          },
        ),
        const SizedBox(height: 12),
        _buildRemoteTextField(
          hintText: 'Senha',
          controller: _passwordController,
          placeholderFocusNode: _passwordFocusNode,
          editFocusNode: _passwordEditFocusNode,
          active: _passwordActive,
          onActivateField: _activatePasswordField,
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            setState(() => _passwordActive = false);
            _submitFocusNode.requestFocus();
          },
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
          focusNode: _submitFocusNode,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildRemoteTextField({
    required String hintText,
    required TextEditingController controller,
    required FocusNode placeholderFocusNode,
    required FocusNode editFocusNode,
    required bool active,
    required VoidCallback onActivateField,
    required IconData prefixIcon,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    if (active) {
      return GlassInput(
        hintText: hintText,
        controller: controller,
        focusNode: editFocusNode,
        autofocus: true,
        obscureText: obscureText,
        keyboardType: keyboardType,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        onSuffixTap: onSuffixTap,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
      );
    }

    return Focus(
      focusNode: placeholderFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown) {
          if (placeholderFocusNode == _usernameFocusNode) {
            _passwordFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (placeholderFocusNode == _passwordFocusNode) {
            _submitFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }

        if (key == LogicalKeyboardKey.arrowUp &&
            placeholderFocusNode == _passwordFocusNode) {
          _usernameFocusNode.requestFocus();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.gameButtonA) {
          onActivateField();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      onFocusChange: (_) {
        if (mounted) setState(() {});
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      },
      child: GestureDetector(
        onTap: onActivateField,
        child: BlinkingCursorPlaceholder(
          text: obscureText && controller.text.isNotEmpty ? '********' : controller.text,
          hintText: hintText,
          isFocused: placeholderFocusNode.hasFocus,
          onActivate: onActivateField,
          prefixIcon: prefixIcon,
          focusedColor: AppColors.primary,
        ),
      ),
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
        const _InfoItem(text: '1. O administrador cria seu usuário no Click SaaS.',
        ),
        const SizedBox(height: 10),
        const _InfoItem(text: '2. O conteúdo é liberado manualmente na plataforma parceira.'),
        const SizedBox(height: 10),
        const _InfoItem(text: '3. Depois disso, seu acesso já entra com a lista configurada automaticamente.'),
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

class _OfficialAppMark extends StatelessWidget {
  const _OfficialAppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.primary,
              child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 42),
            );
          },
        ),
      ),
    );
  }
}
