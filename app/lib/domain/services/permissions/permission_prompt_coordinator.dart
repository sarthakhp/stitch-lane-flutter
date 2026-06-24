import 'package:flutter/material.dart';

import '../../state/permission_controller.dart';
import '../../../presentation/widgets/permissions/permission_explainer_dialog.dart';

/// Decides *when* and *how* to ask for permissions, given the current
/// [PermissionController] state. Two entry points cover every case:
///
/// - [runFirstTimeIfNeeded] — called from the main shell on first frame.
///   Shows our friendly explainer dialog once per install, then defers to
///   the native batch if the user accepts.
/// - [runRecoveryFlow] — called from the banner tap. Picks the right
///   action (native prompt vs system settings) based on whether anything
///   is permanently denied.
///
/// Keeping flow logic out of the controller means the controller stays
/// `BuildContext`-free and unit-testable, while the screen layer can
/// stitch dialogs / settings deep-links into one call.
class PermissionPromptCoordinator {
  PermissionPromptCoordinator._();

  /// Show the explainer-then-request flow exactly once per install, only
  /// if at least one permission is currently missing. No-op otherwise.
  ///
  /// Returns once the flow settles (user dismissed or finished requesting).
  static Future<void> runFirstTimeIfNeeded(
    BuildContext context,
    PermissionController controller,
  ) async {
    if (controller.hasCompletedFirstTimePrompt) return;
    if (!controller.hasAnyMissing) {
      // Nothing to ask for — still mark complete so we never show it later
      // for this install.
      await controller.markFirstTimePromptCompleted();
      return;
    }

    final accepted = await PermissionExplainerDialog.show(context);
    // Whatever the user picked, the explainer has been shown — record it so
    // we don't pester them again. The banner remains as the persistent
    // recovery surface.
    await controller.markFirstTimePromptCompleted();

    if (accepted == true && context.mounted) {
      await controller.requestAll();
    }
  }

  /// Banner-tap handler. If any permission is permanently denied, jump to
  /// system settings (the native prompt would silently no-op). Otherwise
  /// fire the native request batch directly.
  static Future<void> runRecoveryFlow(
    BuildContext context,
    PermissionController controller,
  ) async {
    if (controller.anyPermanentlyDenied) {
      await controller.openSystemSettings();
      return;
    }
    await controller.requestAll();
  }
}
