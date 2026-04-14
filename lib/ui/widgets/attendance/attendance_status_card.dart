import 'package:flutter/material.dart';

import '../app_chrome.dart';

class AttendanceStatusCard extends StatelessWidget {
  const AttendanceStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.actionLoading = false,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool actionLoading;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppStatusCard(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      actionLoading: actionLoading,
      onAction: onAction,
    );
  }
}
