import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../data/api_client.dart';
import 'app_chrome.dart';

enum AuthPasswordSheetMode {
  requestReset,
  changePassword,
}

class AuthPasswordSheet extends StatefulWidget {
  const AuthPasswordSheet({
    super.key,
    required this.mode,
    this.initialEmail,
    this.isRecoveryFlow = false,
  });

  final AuthPasswordSheetMode mode;
  final String? initialEmail;
  final bool isRecoveryFlow;

  @override
  State<AuthPasswordSheet> createState() => _AuthPasswordSheetState();
}

class _AuthPasswordSheetState extends State<AuthPasswordSheet> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isResetRequest => widget.mode == AuthPasswordSheetMode.requestReset;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _submit() async {
    final session = AppSessionScope.read(context);

    setState(() {
      _errorMessage = null;
    });

    if (_isResetRequest) {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        setState(() {
          _errorMessage = 'Inserisci l email del tuo account';
        });
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final message = await session.requestPasswordReset(email: email);
        if (!mounted) return;
        Navigator.pop(context, message);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }

      return;
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Compila entrambe le password';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Le password non coincidono';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final message = await session.updatePassword(password: password);
      if (!mounted) return;
      Navigator.pop(context, message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Icon(
                    _isResetRequest
                        ? Icons.mark_email_unread_outlined
                        : Icons.lock_reset_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isResetRequest
                          ? 'Recupera password'
                          : widget.isRecoveryFlow
                              ? 'Imposta nuova password'
                              : 'Cambia password',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isResetRequest
                    ? 'Inserisci la tua email: ti invieremo un link per reimpostare la password.'
                    : widget.isRecoveryFlow
                        ? 'Sei entrato dal link di recupero. Scegli subito una nuova password per completare l accesso.'
                        : 'Aggiorna la password del tuo account con una nuova password sicura.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UltrasAppTheme.textMuted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 18),
              if (_isResetRequest) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration:
                      _decoration('Email', icon: Icons.alternate_email_outlined),
                  enabled: !_isSubmitting,
                ),
              ] else ...[
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration:
                      _decoration('Nuova password', icon: Icons.lock_outline),
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: _decoration(
                    'Conferma nuova password',
                    icon: Icons.lock_reset_outlined,
                  ),
                  enabled: !_isSubmitting,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting
                        ? 'Attendi...'
                        : _isResetRequest
                            ? 'Invia link di recupero'
                            : 'Aggiorna password',
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
