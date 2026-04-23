import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/api_client.dart';
import 'app_chrome.dart';
import 'auth_password_sheet.dart';
import 'clubline_brand_logo.dart';

enum AuthSheetMode { signIn, signUp }

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key, this.initialMode = AuthSheetMode.signIn});

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

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  bool _isEmailRateLimitMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('limite temporaneo') &&
            normalized.contains('email di verifica') ||
        (normalized.contains('rate limit') && normalized.contains('email'));
  }

  String _friendlyErrorMessage(String message) {
    if (_isEmailRateLimitMessage(message)) {
      return 'Stiamo inviando troppe email di verifica in questo momento. Attendi un attimo, poi riprova. Prima di ripetere la registrazione controlla anche Posta indesiderata o Promozioni.';
    }

    return message;
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
        await session.signInWithEmail(email: email, password: password);
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      await session.signUpWithEmail(email: email, password: password);

      if (!mounted) return;

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        isSubmitting = false;
        errorMessage = _friendlyErrorMessage(e.message);
      });
    } catch (e) {
      setState(() {
        isSubmitting = false;
        errorMessage = _friendlyErrorMessage(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final horizontalPadding = AppResponsive.horizontalPadding(context) + 4;
    final isSignIn = selectedMode == AuthSheetMode.signIn;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: 10,
          bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
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
                        color: ClublineAppTheme.outlineStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppAdaptiveColumns(
                    breakpoint: 760,
                    gap: AppResponsive.sectionGap(context),
                    flex: const [5, 4],
                    children: [
                      AppHeroPanel(
                        eyebrow: isSignIn ? 'Bentornato' : 'Nuovo account',
                        title: isSignIn
                            ? 'Entra in Clubline'
                            : 'Crea il tuo accesso',
                        subtitle: isSignIn
                            ? 'Accedi e riprendi subito il flusso del tuo club su web, iPhone e Android.'
                            : 'Registrati, crea il tuo giocatore e poi scegli se fondare un club o unirti a una squadra esistente.',
                        media: Center(
                          child: ClublineBrandLogo(width: compact ? 170 : 210),
                        ),
                        badges: [
                          const AppStatusBadge(
                            label: 'Multi-club',
                            tone: AppStatusTone.info,
                          ),
                          AppStatusBadge(
                            label: isSignIn
                                ? 'Login sicuro'
                                : 'Accesso immediato',
                            tone: AppStatusTone.success,
                          ),
                        ],
                        footer: AppResponsiveGrid(
                          minChildWidth: 170,
                          gap: AppSpacing.sm,
                          children: const [
                            AppMetricCard(
                              label: 'Flusso account',
                              value: '1 accesso',
                              icon: Icons.login_outlined,
                              caption: 'Email e password',
                            ),
                            AppMetricCard(
                              label: 'Onboarding',
                              value: '1 giocatore',
                              icon: Icons.badge_outlined,
                              caption: 'Profilo unico riusabile',
                            ),
                            AppMetricCard(
                              label: 'Prossimo step',
                              value: 'Club',
                              icon: Icons.shield_outlined,
                              caption: 'Crea o richiedi ingresso',
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                      AppSurfaceCard(
                        icon: isSignIn
                            ? Icons.login_outlined
                            : Icons.person_add_alt_1_outlined,
                        title: isSignIn
                            ? 'Accesso account'
                            : 'Registrazione account',
                        subtitle: isSignIn
                            ? 'Usa le tue credenziali per entrare nel progetto Clubline.'
                            : 'Completa i dati essenziali. Il resto del flusso avviene dentro l app.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            if (!isSignIn) ...[
                              const SizedBox(height: AppSpacing.md),
                              const AppBanner(
                                message:
                                    'Con la configurazione attuale, dopo la registrazione entrerai direttamente nell app.',
                                tone: AppStatusTone.info,
                                icon: Icons.info_outline,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: _decoration(
                                'Email',
                                icon: Icons.alternate_email_outlined,
                              ),
                              enabled: !isSubmitting,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: _decoration(
                                'Password',
                                icon: Icons.lock_outline,
                              ),
                              enabled: !isSubmitting,
                            ),
                            if (isSignIn) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : _openPasswordResetSheet,
                                  child: const Text('Password dimenticata?'),
                                ),
                              ),
                            ],
                            if (!isSignIn) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: confirmPasswordController,
                                obscureText: true,
                                decoration: _decoration(
                                  'Conferma password',
                                  icon: Icons.lock_reset_outlined,
                                ),
                                enabled: !isSubmitting,
                              ),
                            ],
                            if (errorMessage != null) ...[
                              const SizedBox(height: 14),
                              AppBanner(
                                message: errorMessage!,
                                tone: _isEmailRateLimitMessage(errorMessage!)
                                    ? AppStatusTone.info
                                    : AppStatusTone.error,
                                icon: _isEmailRateLimitMessage(errorMessage!)
                                    ? Icons.schedule_outlined
                                    : Icons.error_outline,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            AppActionButton(
                              label: isSubmitting
                                  ? 'Attendi...'
                                  : isSignIn
                                  ? 'Accedi'
                                  : 'Crea account',
                              icon: isSignIn
                                  ? Icons.arrow_forward_outlined
                                  : Icons.person_add_alt_1_outlined,
                              expand: true,
                              isLoading: isSubmitting,
                              onPressed: isSubmitting ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
