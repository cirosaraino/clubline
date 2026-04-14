import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/api_client.dart';
import 'app_chrome.dart';
import 'auth_password_sheet.dart';

enum AuthSheetMode { signIn, signUp }

class AuthSheet extends StatefulWidget {
  const AuthSheet({
    super.key,
    this.initialMode = AuthSheetMode.signIn,
  });

  final AuthSheetMode initialMode;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  late AuthSheetMode selectedMode;
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    selectedMode = widget.initialMode;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _openPasswordResetSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AuthPasswordSheet(
        mode: AuthPasswordSheetMode.requestReset,
        initialEmail: emailController.text.trim(),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Compila email e password';
      });
      return;
    }

    if (selectedMode == AuthSheetMode.signUp && password != confirmPassword) {
      setState(() {
        errorMessage = 'Le password non coincidono';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      final session = AppSessionScope.read(context);
      if (selectedMode == AuthSheetMode.signIn) {
        await session.signInWithEmail(
          email: email,
          password: password,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final message = await session.signUpWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (session.isAuthenticated) {
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } on ApiException catch (e) {
      setState(() {
        isSubmitting = false;
        errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        isSubmitting = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AppSessionScope.of(context);
    final isCaptainRegistrationOpen = !session.players.any((player) => player.hasLinkedAuthAccount);
    final compact = AppResponsive.isCompact(context);
    final horizontalPadding = AppResponsive.horizontalPadding(context) + 4;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: 10,
          bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: UltrasAppTheme.outlineStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedMode == AuthSheetMode.signIn
                          ? 'Accedi alla squadra'
                          : 'Registrati nella squadra',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                selectedMode == AuthSheetMode.signIn
                    ? 'Usa email e password per entrare con il tuo account.'
                    : 'Crea il tuo account e poi completa il profilo squadra.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: UltrasAppTheme.textMuted,
                  height: 1.35,
                ),
              ),
              if (selectedMode == AuthSheetMode.signUp && isCaptainRegistrationOpen) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    'Registrazione capitano iniziale aperta: il primo account che completa il primo profilo squadra verra impostato automaticamente come capitano.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AuthSheetMode>(
                  segments: const [
                    ButtonSegment<AuthSheetMode>(
                      value: AuthSheetMode.signIn,
                      label: Text('Accedi'),
                      icon: Icon(Icons.login_outlined),
                    ),
                    ButtonSegment<AuthSheetMode>(
                      value: AuthSheetMode.signUp,
                      label: Text('Registrati'),
                      icon: Icon(Icons.person_add_alt_1_outlined),
                    ),
                  ],
                  selected: {selectedMode},
                  onSelectionChanged: isSubmitting
                      ? null
                      : (selection) {
                          setState(() {
                            selectedMode = selection.first;
                            errorMessage = null;
                          });
                        },
                  style: compact
                      ? ButtonStyle(
                          visualDensity: const VisualDensity(
                            horizontal: -1,
                            vertical: -1,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _decoration('Email', icon: Icons.alternate_email_outlined),
                enabled: !isSubmitting,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: _decoration('Password', icon: Icons.lock_outline),
                enabled: !isSubmitting,
              ),
              if (selectedMode == AuthSheetMode.signIn) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isSubmitting ? null : _openPasswordResetSheet,
                    child: const Text('Password dimenticata?'),
                  ),
                ),
              ],
              if (selectedMode == AuthSheetMode.signUp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: _decoration('Conferma password', icon: Icons.lock_reset_outlined),
                  enabled: !isSubmitting,
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  child: Text(
                    isSubmitting
                        ? 'Attendi...'
                        : selectedMode == AuthSheetMode.signIn
                            ? 'Accedi'
                            : 'Crea account',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
