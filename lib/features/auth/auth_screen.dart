import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/my_game_list_logo.dart';
import '../integrations/integration_contracts.dart';

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MyGameListLogo(iconSize: 28, fontSize: 21),
          const SizedBox(height: 24),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
    title: 'Entrar',
    subtitle: 'Acesse sua conta para entrar na sua biblioteca',
    footer: _legalLinks(context),
    children: [
      AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !_busy,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Informe sua senha.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _busy ? null : _showPasswordResetDialog,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            textStyle: const TextStyle(
              decoration: TextDecoration.underline,
              decorationThickness: 1.2,
            ),
          ),
          child: const Text('Esqueci minha senha'),
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _busy ? null : _submit,
        style: AppTheme.primaryActionButtonStyle(),
        icon: _busy
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login_rounded),
        label: Text(_busy ? 'Aguarde…' : 'Entrar'),
      ),
      const SizedBox(height: 14),
      _GoogleButton(
        text: 'Entrar com Google',
        enabled: !_busy,
        onPressed: _signInWithGoogle,
      ),
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ainda não tem conta?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          _AuthLinkButton(
            label: 'Cadastre-se',
            onPressed: _busy ? null : () => context.go('/register'),
          ),
        ],
      ),
    ],
  );

  Widget _legalLinks(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    final linkStyle = style?.copyWith(decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Ao continuar, você concorda com os '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: () => context.push('/terms'),
              child: Text('Termos de Uso', style: linkStyle),
            ),
          ),
          const TextSpan(text: ' e a '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: () => context.push('/privacy'),
              child: Text('Política de Privacidade', style: linkStyle),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref
          .read(authGatewayProvider)
          .signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } catch (error) {
      if (mounted) _showMessage(_authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      await ref.read(authGatewayProvider).signInWithGoogle();
    } catch (error) {
      if (mounted && !_isGoogleSignInCancellation(error)) {
        _showMessage(_authErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();
    var sending = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> sendReset() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() => sending = true);
            var feedback =
                'Se o e-mail estiver associado a uma conta, enviaremos as instruções de recuperação.';
            try {
              await ref
                  .read(authGatewayProvider)
                  .sendPasswordResetEmail(controller.text.trim());
            } on FirebaseAuthException catch (error) {
              if (error.code != 'user-not-found') {
                feedback = _authErrorMessage(error);
              }
            } catch (error) {
              feedback = _authErrorMessage(error);
            }
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            if (mounted) _showMessage(feedback);
          }

          return AlertDialog(
            title: const Text('Recuperar senha'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Informe seu e-mail. Se ele estiver associado a uma conta, você receberá as instruções para criar uma nova senha.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => sendReset(),
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: _emailValidator,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: sending ? null : sendReset,
                child: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _confirmInteracted = false;
  bool _submitted = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
    title: 'Criar conta',
    subtitle: 'Crie sua conta e comece sua jornada gamer',
    footer: const SizedBox.shrink(),
    children: [
      AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.newUsername,
                  AutofillHints.email,
                ],
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _emailValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                enabled: !_busy,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) {
                  setState(() {});
                  if (_confirmInteracted) {
                    _confirmFieldKey.currentState?.validate();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) => _isValidPassword(value ?? '')
                    ? null
                    : 'A senha ainda não atende aos requisitos.',
              ),
              const SizedBox(height: 8),
              _PasswordStrengthIndicator(password: _passwordController.text),
              const SizedBox(height: 12),
              TextFormField(
                key: _confirmFieldKey,
                controller: _confirmController,
                enabled: !_busy,
                obscureText: !_showConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) {
                  setState(() => _confirmInteracted = true);
                },
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Confirmar senha',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _showConfirm
                        ? 'Ocultar confirmação'
                        : 'Mostrar confirmação',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showConfirm = !_showConfirm),
                    icon: Icon(
                      _showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _submitted ? 'Confirme sua senha.' : null;
                  }
                  if (_confirmInteracted && value != _passwordController.text) {
                    return 'As senhas não coincidem.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _busy ? null : _submit,
        style: AppTheme.primaryActionButtonStyle(),
        icon: _busy
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_busy ? 'Aguarde…' : 'Criar conta'),
      ),
      const SizedBox(height: 14),
      _GoogleButton(
        text: 'Continuar com Google',
        enabled: !_busy,
        onPressed: _signInWithGoogle,
      ),
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Já tem uma conta?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          _AuthLinkButton(
            label: 'Entrar',
            onPressed: _busy ? null : () => context.go('/login'),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ],
  );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _confirmInteracted = true;
    });
    if (!_formKey.currentState!.validate()) return;
    if (!_isValidPassword(_passwordController.text)) {
      _showMessage('A senha precisa atender a todos os requisitos.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      _showMessage('As senhas não coincidem.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(authGatewayProvider)
          .createAccountWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } catch (error) {
      if (mounted) _showMessage(_authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      await ref.read(authGatewayProvider).signInWithGoogle();
    } catch (error) {
      if (mounted && !_isGoogleSignInCancellation(error)) {
        _showMessage(_authErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;
    const headerDark = AppColors.ink;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: background)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 310,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/img_fundo.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        headerDark.withValues(alpha: .9),
                        headerDark.withValues(alpha: .55),
                        headerDark.withValues(alpha: .18),
                      ],
                      stops: const [0, .58, 1],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        headerDark.withValues(alpha: .25),
                        headerDark.withValues(alpha: .15),
                        background.withValues(alpha: .35),
                        background,
                      ],
                      stops: const [0, .48, .84, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 44),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MyGameListLogo(iconSize: 38, fontSize: 27),
                      const SizedBox(height: 56),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 62,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontSize: 44,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.white.withValues(
                                      alpha: .82,
                                    ),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      ...children,
                      if (footer is! SizedBox) ...[
                        const SizedBox(height: 34),
                        footer,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.text,
    required this.enabled,
    required this.onPressed,
  });

  final String text;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: enabled ? onPressed : null,
    icon: const FaIcon(
      FontAwesomeIcons.google,
      size: 23,
      color: Color(0xFF4285F4),
    ),
    label: Text(text),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSpace.primaryButtonHeight),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.navy.withValues(alpha: .84)
          : Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      shape: AppSpace.buttonShape,
      overlayColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
    ),
  );
}

class _AuthLinkButton extends StatelessWidget {
  const _AuthLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        overlayColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: accent,
          decorationThickness: 1.5,
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = _PasswordStrength.evaluate(password);
    final requirements = <(String, bool)>[
      ('Mín. 8', password.length >= 8),
      ('Letra', RegExp(r'[A-Za-z]').hasMatch(password)),
      ('Número', RegExp(r'\d').hasMatch(password)),
      ('Símbolo', RegExp(r'[^A-Za-z0-9]').hasMatch(password)),
    ];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Força da senha',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (password.isNotEmpty)
              Text(
                strength.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: strength.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (index) {
            final active = password.isNotEmpty && index < strength.segments;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 5,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                decoration: BoxDecoration(
                  color: active
                      ? strength.color
                      : theme.colorScheme.outlineVariant.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 3,
          children: requirements
              .map(
                (requirement) => _PasswordRequirement(
                  label: requirement.$1,
                  met: requirement.$2,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met
        ? AppColors.green
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 11),
        ),
      ],
    );
  }
}

class _PasswordStrength {
  const _PasswordStrength(this.score, this.label, this.color);

  final int score;
  final String label;
  final Color color;

  int get segments => score;

  static _PasswordStrength evaluate(String password) {
    if (password.isEmpty) {
      return const _PasswordStrength(-1, 'Muito fraca', Color(0xFFE15C5C));
    }

    final requirementCount = [
      password.length >= 8,
      RegExp(r'[A-Za-z]').hasMatch(password),
      RegExp(r'\d').hasMatch(password),
      RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    ].where((isMet) => isMet).length;

    if (requirementCount == 0) {
      return const _PasswordStrength(0, 'Muito fraca', Color(0xFFE15C5C));
    }
    if (requirementCount == 1) {
      return const _PasswordStrength(1, 'Fraca', Color(0xFFE9754D));
    }
    if (requirementCount == 2) {
      return const _PasswordStrength(2, 'Fraca', Color(0xFFFF9C4A));
    }
    if (requirementCount == 3) {
      return const _PasswordStrength(3, 'Média', Color(0xFFF5C542));
    }

    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    if (hasLowercase && hasUppercase) {
      return const _PasswordStrength(5, 'Muito forte', Color(0xFF55C6A2));
    }
    return const _PasswordStrength(4, 'Forte', Color(0xFF9BCB65));
  }
}

bool _isValidPassword(String password) =>
    password.length >= 8 &&
    RegExp(r'[A-Za-z]').hasMatch(password) &&
    RegExp(r'\d').hasMatch(password) &&
    RegExp(r'[^A-Za-z0-9]').hasMatch(password);

bool _isGoogleSignInCancellation(Object error) =>
    (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) ||
    (error is FirebaseAuthException &&
        (error.code == 'popup-closed-by-user' ||
            error.code == 'cancelled-popup-request'));

String? _emailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe seu e-mail.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String _authErrorMessage(Object error) {
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'O acesso com Google precisa ser configurado para este aplicativo.',
      _ => 'Não foi possível entrar com Google. Tente novamente.',
    };
  }
  if (error is IntegrationNotConfiguredException) return error.toString();
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'email-already-in-use' => 'Este e-mail já possui uma conta.',
      'invalid-email' => 'O formato do e-mail é inválido.',
      'weak-password' => 'Escolha uma senha que atenda aos requisitos.',
      'operation-not-allowed' =>
        'O provedor de autenticação ainda não está habilitado no Firebase.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'E-mail ou senha incorretos.',
      'account-exists-with-different-credential' ||
      'credential-already-in-use' =>
        'Já existe uma conta com este e-mail. Entre usando o método original.',
      'network-request-failed' =>
        'Sem conexão. Verifique a internet e tente novamente.',
      'too-many-requests' => 'Muitas tentativas. Aguarde e tente novamente.',
      'user-disabled' =>
        'Esta conta está desativada. Entre em contato com o suporte.',
      _ => 'Não foi possível acessar a conta. Tente novamente.',
    };
  }
  return 'Não foi possível acessar a conta. Verifique sua conexão e tente novamente.';
}
