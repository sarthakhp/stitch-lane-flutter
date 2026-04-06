import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/services/ai_chat_models.dart';
import '../../../utils/app_logger.dart';
import 'ai_component_card.dart';

class AiMessageBubble extends StatelessWidget {
  final AiChatMessage message;

  const AiMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.isUser;

    final hasCustomers = !isUser && message.uiComponents.any((c) => c.type == 'customer');
    final hasOrders = !isUser && message.uiComponents.any((c) => c.type == 'order');

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacing12,
              vertical: AppConfig.spacing8,
            ),
            decoration: BoxDecoration(
              color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
              ),
            ),
            child: isUser
                ? SelectableText(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      strong: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      tableHead: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      tableBody: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      tableBorder: TableBorder.all(
                        color: colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                      tableCellsPadding: const EdgeInsets.symmetric(
                        horizontal: AppConfig.spacing8,
                        vertical: AppConfig.spacing4,
                      ),
                      listBullet: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      code: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    selectable: true,
                  ),
          ),
        ),
        if (hasCustomers)
          _buildLabeledCarousel(
            context,
            'Customers',
            message.uiComponents.where((c) => c.type == 'customer').toList(),
          ),
        if (hasOrders)
          _buildLabeledCarousel(
            context,
            'Orders',
            message.uiComponents.where((c) => c.type == 'order').toList(),
          ),
      ],
    );
  }

  Widget _buildLabeledCarousel(BuildContext context, String label, List<UiComponent> components) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppConfig.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConfig.spacing4),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: components.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppConfig.spacing8),
              itemBuilder: (context, index) => AiComponentCard(
                component: components[index],
                onTap: () => _navigateToComponent(context, components[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToComponent(BuildContext context, UiComponent component) async {
    try {
      final customerRepo = context.read<CustomerRepository>();

      if (component.type == 'customer') {
        final customer = await customerRepo.getCustomerById(component.id);
        if (customer != null && context.mounted) {
          Navigator.pushNamed(context, AppConstants.customerDetailRoute, arguments: customer);
        }
      } else if (component.type == 'order') {
        final orderRepo = context.read<OrderRepository>();
        final order = await orderRepo.getOrderById(component.id);
        if (order != null && context.mounted) {
          final customer = await customerRepo.getCustomerById(order.customerId);
          if (customer != null && context.mounted) {
            Navigator.pushNamed(context, AppConstants.orderDetailRoute, arguments: {
              'order': order,
              'customer': customer,
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to navigate to ${component.type}', e);
    }
  }
}
