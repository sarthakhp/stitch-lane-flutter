import 'package:flutter/material.dart';

/// Low-emphasis destructive action placed at the very end of a detail screen's
/// scroll. Delete is rare, so it lives out of the way at the bottom rather than
/// in the header — and stays compact (content-sized, centered) so it isn't a
/// large accidental-tap target.
class DeleteEntityButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const DeleteEntityButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: error,
          backgroundColor: Colors.transparent,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
