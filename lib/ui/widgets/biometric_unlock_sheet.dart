import 'package:flutter/material.dart';

import '../../core/biometric_auth/biometric_unlock_controller.dart';
import 'app_chrome.dart';

class BiometricUnlockSheet extends StatelessWidget {
  const BiometricUnlockSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BiometricUnlockScope.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppResponsive.horizontalPadding(context),
          AppSpacing.lg,
          AppResponsive.horizontalPadding(context),
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                title: 'Sblocco biometrico',
                subtitle:
                    'Proteggi localmente una sessione Clubline gia autenticata senza salvare password sul dispositivo.',
                eyebrow: 'Sicurezza locale',
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Abilita ${controller.preferenceLabel}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  controller.availabilityDescription,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Switch.adaptive(
                            value: controller.isBiometricUnlockEnabled,
                            onChanged: controller.isCheckingConfiguration
                                ? null
                                : (value) async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final error = await controller
                                        .setBiometricUnlockEnabled(value);
                                    if (!context.mounted) {
                                      return;
                                    }

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error ??
                                              (value
                                                  ? 'Sblocco biometrico attivato.'
                                                  : 'Sblocco biometrico disattivato.'),
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                      if (controller.isCheckingConfiguration ||
                          controller.isPrompting) ...[
                        const SizedBox(height: AppSpacing.md),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Come funziona',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _BiometricInfoLine(
                        text:
                            'Lo sblocco biometrico protegge solo una sessione gia autenticata con Supabase.',
                      ),
                      const _BiometricInfoLine(
                        text:
                            'Le password non vengono salvate. Clubline usa il sistema biometrico del dispositivo.',
                      ),
                      const _BiometricInfoLine(
                        text:
                            'Se preferisci, puoi sempre uscire e rientrare con il login normale.',
                      ),
                    ],
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

class _BiometricInfoLine extends StatelessWidget {
  const _BiometricInfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
