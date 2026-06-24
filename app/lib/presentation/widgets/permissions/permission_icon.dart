import 'package:flutter/material.dart';

import '../../../domain/services/permissions/app_permission.dart';

/// Maps an [AppPermission] to its display icon. Lives in the UI layer
/// because icons are a Material concern — the domain enum stays free of
/// Flutter imports. Centralised so dialog and banner stay consistent.
class PermissionIcon extends StatelessWidget {
  final AppPermission permission;
  final Color? color;
  final double size;

  const PermissionIcon({
    super.key,
    required this.permission,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(_iconFor(permission), color: color, size: size);
  }

  static IconData _iconFor(AppPermission p) => switch (p) {
        AppPermission.microphone => Icons.mic_outlined,
        AppPermission.notification => Icons.notifications_outlined,
        AppPermission.contacts => Icons.contacts_outlined,
      };
}
