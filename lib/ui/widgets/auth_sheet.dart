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

  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    return trimmed.contains('@') && trimmed.contains('.');
  }

  String? _validateInputs({
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (email.isEmpty) {
      return 'Inserisci l email';
    }

    if (!_isValidEmail(email)) {
      return 'Inserisci un email valida';
    }

    if (password.isEmpty) {
      return 'Inserisci la password';
    }

    if (selectedMode == AuthSheetMode.signUp && confirmPassword.isEmpty) {
      return 'Conferma la password';
    }

    if (selectedMode == AuthSheetMode.signUp && password != confirmPassword) {
      return 'Le password non coincidono';
    }

    return null;
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    FocusScope.of(context).unfocus();

    final validationError = _validateInputs(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (validationError != null) {
      setState(() {
        errorMessage = validationError;
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

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: ClublineAppTheme.outlineStrong,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, bool isSignIn) {
    return Column(
      children: [
        ClublineBrandLogo(width: 106),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isSignIn ? 'Accedi' : 'Registrati',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isSignIn ? 'Entra nel tuo account.' : 'Crea il tuo account.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: ClublineAppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildDesktopIntro(BuildContext context, bool isSignIn) {
    return AppSurfaceCard(
      icon: Icons.shield_outlined,
      title: 'Clubline',
      subtitle: isSignIn
          ? 'Accedi e torna subito al tuo club.'
          : 'Registrati e inizia dal tuo giocatore.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: ClublineBrandLogo(width: 170)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppStatusBadge(
                label: isSignIn ? 'Accesso rapido' : 'Partenza rapida',
                tone: AppStatusTone.success,
              ),
              const AppStatusBadge(
                label: 'Web • iPhone • Android',
                tone: AppStatusTone.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context, bool compact) {
    return SizedBox(
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
    );
  }

  Widget _buildFormCard(BuildContext context, bool isSignIn, bool compact) {
    final submissionBannerMessage = isSignIn
        ? 'Accesso in corso... Stiamo verificando sessione, profilo e stato del club. Se il server si sta riattivando potrebbero volerci alcuni secondi.'
        : 'Creazione account in corso... Stiamo preparando il tuo accesso.';

    return AppSurfaceCard(
      icon: isSignIn ? Icons.login_outlined : Icons.person_add_alt_1_outlined,
      title: isSignIn ? 'Accedi' : 'Registrati',
      subtitle: isSignIn ? 'Email e password' : 'Crea il tuo accesso',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeToggle(context, compact),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              autocorrect: false,
              enableSuggestions: false,
              decoration: _decoration(
                'Email',
                icon: Icons.alternate_email_outlined,
              ),
              enabled: !isSubmitting,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: passwordController,
              obscureText: true,
              textInputAction: isSignIn
                  ? TextInputAction.done
                  : TextInputAction.next,
              autofillHints: isSignIn
                  ? const [AutofillHints.password]
                  : const [AutofillHints.newPassword],
              decoration: _decoration('Password', icon: Icons.lock_outline),
              enabled: !isSubmitting,
              onSubmitted: isSignIn && !isSubmitting ? (_) => _submit() : null,
            ),
            if (isSignIn) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isSubmitting ? null : _openPasswordResetSheet,
                  child: const Text('Password dimenticata?'),
                ),
              ),
            ],
            if (!isSignIn) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _decoration(
                  'Conferma password',
                  icon: Icons.lock_reset_outlined,
                ),
                enabled: !isSubmitting,
                onSubmitted: isSubmitting ? null : (_) => _submit(),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
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
            if (isSubmitting) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBanner(
                message: submissionBannerMessage,
                tone: AppStatusTone.info,
                icon: Icons.hourglass_top_outlined,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppActionButton(
              label: isSubmitting
                  ? isSignIn
                        ? 'Accesso in corso...'
                        : 'Creazione account...'
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);
    final horizontalPadding = AppResponsive.horizontalPadding(context);
    final isSignIn = selectedMode == AuthSheetMode.signIn;
    final content = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDragHandle(),
              const SizedBox(height: AppSpacing.md),
              _buildCompactHeader(context, isSignIn),
              const SizedBox(height: AppSpacing.md),
              _buildFormCard(context, isSignIn, compact),
            ],
          )
        : AppAdaptiveColumns(
            breakpoint: 760,
            gap: AppResponsive.sectionGap(context),
            flex: const [4, 5],
            children: [
              _buildDesktopIntro(context, isSignIn),
              _buildFormCard(context, isSignIn, compact),
            ],
          );

    return PopScope(
      canPop: !isSubmitting,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: compact ? 8 : 12,
            bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 440 : 860),
              child: SingleChildScrollView(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
