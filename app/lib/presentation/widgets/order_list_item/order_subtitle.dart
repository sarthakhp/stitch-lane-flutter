import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../backend/models/order.dart';
import '../../../config/app_config.dart';
import '../../../utils/markdown_helper.dart';

class OrderSubtitle extends StatelessWidget {
  final Order order;
  final String? customerName;
  final bool isDueSoon;

  const OrderSubtitle({
    super.key,
    required this.order,
    this.customerName,
    required this.isDueSoon,
  });

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  String? _getDescriptionPreview() {
    if (order.description != null && order.description!.isNotEmpty) {
      return MarkdownHelper.getPreviewText(
        order.description!,
        maxLength: AppConfig.descriptionPreviewLength,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final descriptionPreview = _getDescriptionPreview();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConfig.spacing4),
        Text(
          'Created: ${_formatDate(order.created)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppConfig.spacing4),
        Text(
          'Due: ${_formatDate(order.dueDate)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDueSoon ? colorScheme.error : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (order.title != null && order.title!.isNotEmpty) ...[
          const SizedBox(height: AppConfig.spacing4),
          Text(
            'Title: ${order.title!}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (descriptionPreview != null) ...[
          const SizedBox(height: AppConfig.spacing4),
          Text(
            descriptionPreview,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

