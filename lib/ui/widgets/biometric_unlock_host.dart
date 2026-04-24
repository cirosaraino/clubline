import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/biometric_auth/biometric_unlock_controller.dart';
import 'app_chrome.dart';
import 'clubline_brand_logo.dart';

class BiometricUnlockHost extends StatelessWidget {
  const BiometricUnlockHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final biometricController = BiometricUnlockScope.of(context);
    if (!biometricController.shouldBlockAccess) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AbsorbPointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.52),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SafeArea(
                child: Center(
                  child: AppContentFrame(
                    maxWidth: 560,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const ClublineBrandLogo(width: 108),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Sblocca Clubline',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              biometricController.isPreparingInitialGate
                                  ? 'Verifica delle impostazioni di sblocco in corso...'
                                  : biometricController.isPrompting
                                  ? 'Verifica biometrica in corso per sbloccare la sessione gia autenticata.'
                                  : 'Usa ${biometricController.preferenceLabel} per sbloccare la sessione attiva su questo dispositivo.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (biometricController.statusMessage != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                biometricController.statusMessage!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            if (biometricController.isPreparingInitialGate ||
                                biometricController.isPrompting)
                              const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: CircularProgressIndicator(),
                              )
                            else
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () =>
                                        biometricController.requestUnlock(),
                                    icon: const Icon(
                                      Icons.fingerprint_outlined,
                                    ),
                                    label: Text(
                                      biometricController.unlockActionLabel,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await AppSessionScope.read(
                                        context,
                                      ).signOut();
                                    },
                                    icon: const Icon(Icons.logout_outlined),
                                    label: const Text('Usa login normale'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
