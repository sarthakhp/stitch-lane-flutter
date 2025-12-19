import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class StickyBottomActionBar extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onSave;
  final String cancelLabel;
  final String saveLabel;
  final bool isLoading;
  final Widget? topWidget;

  const StickyBottomActionBar({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.cancelLabel = 'Cancel',
    this.saveLabel = 'Save',
    this.isLoading = false,
    this.topWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppConfig.spacing16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (topWidget != null) ...[
              topWidget!,
              const SizedBox(height: AppConfig.spacing16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onCancel,
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: AppConfig.spacing16),
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : onSave,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(saveLabel),
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

