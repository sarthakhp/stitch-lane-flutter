import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color containerColor;
  final Color contentColor;
  final VoidCallback onTap;

  const SummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.containerColor,
    required this.contentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: containerColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              _buildIconContainer(),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: _buildContent(theme),
              ),
              Icon(
                Icons.chevron_right,
                color: contentColor.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: contentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      ),
      child: Icon(icon, color: contentColor, size: 28),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: contentColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConfig.spacing4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: contentColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

