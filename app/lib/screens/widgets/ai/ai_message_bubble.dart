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

    final customers = !isUser ? message.uiComponents.where((c) => c.type == 'customer').toList() : <UiComponent>[];
    final orders = !isUser ? message.uiComponents.where((c) => c.type == 'order').toList() : <UiComponent>[];

    // Avatar icon (16) + gap (spacing4=4) + list padding (spacing16*2=32) = ~52
    const avatarSpace = 16.0 + AppConfig.spacing4;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * 0.8 - (isUser ? 0 : avatarSpace);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
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
    );

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isUser)
          Align(alignment: Alignment.centerRight, child: bubble)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppConfig.spacing8),
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppConfig.spacing4),
              Flexible(child: bubble),
            ],
          ),
        if (customers.isNotEmpty)
          _buildLabeledCarousel(
            context,
            customers.length == 1 ? 'Customer' : 'Customers',
            customers,
          ),
        if (orders.isNotEmpty)
          _buildLabeledCarousel(
            context,
            orders.length == 1 ? 'Order' : 'Orders',
            orders,
          ),
      ],
    );
  }

  Widget _buildLabeledCarousel(BuildContext context, String label, List<UiComponent> components) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final carouselHeight = (110.0 * textScale).clamp(100.0, 180.0);

    return Padding(
      padding: const EdgeInsets.only(top: AppConfig.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConfig.spacing4),
          SizedBox(
            height: carouselHeight,
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
