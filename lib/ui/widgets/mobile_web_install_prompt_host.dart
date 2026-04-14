import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../core/mobile_web_install/mobile_web_install_bridge.dart';
import 'app_chrome.dart';

class MobileWebInstallPromptHost extends StatefulWidget {
  const MobileWebInstallPromptHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<MobileWebInstallPromptHost> createState() =>
      _MobileWebInstallPromptHostState();
}

class _MobileWebInstallPromptHostState
    extends State<MobileWebInstallPromptHost> {
  static const _dismissedAtKey = 'mobile_web_install_prompt_dismissed_at_v1';
  static const _acceptedKey = 'mobile_web_install_prompt_accepted_v1';
  static const _dismissCooldown = Duration(days: 7);

  StreamSubscription<void>? _bridgeSubscription;
  bool _hasPromptedThisSession = false;
  bool _isShowingPrompt = false;

  @override
  void initState() {
    super.initState();
    _bridgeSubscription = mobileWebInstall.changes.listen((_) {
      _maybePromptForInstall();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForInstall();
    });
  }

  @override
  void dispose() {
    _bridgeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _maybePromptForInstall() async {
    if (!mounted ||
        _isShowingPrompt ||
        _hasPromptedThisSession ||
        !mobileWebInstall.canSuggestInstall) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    if (!mounted || mobileWebInstall.isStandalone) {
      return;
    }

    if (preferences.getBool(_acceptedKey) == true) {
      return;
    }

    final dismissedAtRaw = preferences.getInt(_dismissedAtKey);
    if (dismissedAtRaw != null) {
      final dismissedAt =
          DateTime.fromMillisecondsSinceEpoch(dismissedAtRaw, isUtc: true);
      if (DateTime.now().toUtc().difference(dismissedAt) < _dismissCooldown) {
        return;
      }
    }

    _hasPromptedThisSession = true;
    _isShowingPrompt = true;

    final action = await showModalBottomSheet<_InstallPromptAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _MobileWebInstallSheet(
        canPromptInstall: mobileWebInstall.canPromptInstall,
        isIosSafari: mobileWebInstall.isIosSafari,
      ),
    );

    _isShowingPrompt = false;
    if (!mounted) {
      return;
    }

    if (action == _InstallPromptAction.install &&
        mobileWebInstall.canPromptInstall) {
      final result = await mobileWebInstall.promptInstall();
      if (!mounted) {
        return;
      }

      switch (result) {
        case MobileWebInstallPromptResult.accepted:
          await preferences.setBool(_acceptedKey, true);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'App aggiunta. La prossima apertura potra avvenire dalla schermata Home.',
              ),
            ),
          );
          return;
        case MobileWebInstallPromptResult.dismissed:
        case MobileWebInstallPromptResult.unavailable:
        case MobileWebInstallPromptResult.unsupported:
          await preferences.setInt(
            _dismissedAtKey,
            DateTime.now().toUtc().millisecondsSinceEpoch,
          );
          return;
      }
    }

    if (action == _InstallPromptAction.install && mobileWebInstall.isIosSafari) {
      await preferences.setInt(
        _dismissedAtKey,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      return;
    }

    await preferences.setInt(
      _dismissedAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

enum _InstallPromptAction {
  dismiss,
  install,
}

class _MobileWebInstallSheet extends StatelessWidget {
  const _MobileWebInstallSheet({
    required this.canPromptInstall,
    required this.isIosSafari,
  });

  final bool canPromptInstall;
  final bool isIosSafari;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppResponsive.horizontalPadding(context) + 2,
          12,
          AppResponsive.horizontalPadding(context) + 2,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconBadge(
                  icon: Icons.download_for_offline_outlined,
                  size: 46,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aggiungi l app al telefono',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              canPromptInstall
                  ? 'Puoi aggiungere l icona di Ultras Mentality alla schermata Home e aprirla come una vera app, piu veloce e pulita.'
                  : isIosSafari
                      ? 'Safari non mostra un popup automatico, ma in pochi tocchi puoi salvare l app nella schermata Home del telefono.'
                      : 'Il browser puo installare l app dal proprio menu. In questo modo avrai l icona sul telefono e un apertura molto piu immediata.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: UltrasAppTheme.textMuted,
                    height: 1.4,
                  ),
            ),
            if (isIosSafari && !canPromptInstall) ...[
              const SizedBox(height: 16),
              _InstructionStep(
                index: 1,
                text: 'Apri il menu Condividi di Safari.',
              ),
              const SizedBox(height: 10),
              _InstructionStep(
                index: 2,
                text: 'Tocca Aggiungi alla schermata Home.',
              ),
              const SizedBox(height: 10),
              _InstructionStep(
                index: 3,
                text: 'Conferma il nome e salva l icona.',
              ),
            ] else if (!canPromptInstall) ...[
              const SizedBox(height: 16),
              _InstructionStep(
                index: 1,
                text: 'Apri il menu principale del browser.',
              ),
              const SizedBox(height: 10),
              _InstructionStep(
                index: 2,
                text: 'Tocca Installa app oppure Aggiungi alla schermata Home.',
              ),
              const SizedBox(height: 10),
              _InstructionStep(
                index: 3,
                text: 'Conferma e usa poi l icona dalla Home del telefono.',
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _InstallPromptAction.dismiss,
                    ),
                    child: const Text('Non ora'),
                  ),
                ),
                SizedBox(
                  width: compact ? double.infinity : null,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _InstallPromptAction.install,
                    ),
                    icon: Icon(
                      canPromptInstall
                          ? Icons.add_to_home_screen_outlined
                          : Icons.ios_share_outlined,
                    ),
                    label: Text(
                      canPromptInstall ? 'Installa app' : 'Mostra istruzioni',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.index,
    required this.text,
  });

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UltrasAppTheme.outlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: UltrasAppTheme.gold.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: UltrasAppTheme.goldSoft,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
