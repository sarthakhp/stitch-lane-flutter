import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../constants/app_constants.dart';
import '../../domain/services/order_service.dart';
import '../../domain/state/auth_state.dart';
import '../../domain/state/order_state.dart';
import '../../domain/state/customer_state.dart';
import '../../domain/state/main_shell_state.dart';
import '../../domain/models/filter_preset.dart';
import '../../domain/models/customer_filter_preset.dart';
import '../../presentation/presentation.dart';
import '../../presentation/widgets/home_action_tile.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text(AppConstants.appName),
        actions: [_buildOverflowMenu(context)],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                context.responsive<double>(
                  compact: AppConfig.spacing16,
                  medium: AppConfig.spacing24,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WelcomeHero(userName: context.watch<AuthState>().userName),
                  const SizedBox(height: AppConfig.spacing16),
                  const BackupHealthCard(),
                  const SizedBox(height: AppConfig.spacing16),
                  if (context.isExpanded)
                    _buildExpandedLayout(context)
                  else
                    _buildStackedLayout(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Phone + portrait-tablet: one column. KPIs and actions still go to a row
  // once there's room (medium); the attention panel sits underneath.
  Widget _buildStackedLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKpiSection(context),
        const SizedBox(height: AppConfig.spacing24),
        _buildActionSection(context),
        const SizedBox(height: AppConfig.spacing24),
        _buildNeedsAttention(context),
      ],
    );
  }

  // Landscape tablet / desktop: two panes — primary actions on the left, the
  // "needs attention" worklist on the right, filling the spare width.
  // Landscape tablet / desktop: KPIs span the top, then two panes below —
  // quick actions on the left, the "needs attention" worklist on the right.
  Widget _buildExpandedLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKpiSection(context),
        const SizedBox(height: AppConfig.spacing24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildActionSection(context),
            ),
            const SizedBox(width: AppConfig.spacing24),
            Expanded(
              flex: 2,
              child: _buildNeedsAttention(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiSection(BuildContext context) {
    return Selector<OrderState, HomeStats>(
      selector: (_, orderState) =>
          OrderService.computeHomeStats(orderState.orders),
      builder: (context, stats, child) {
        final cards = _summaryCards(context, stats);
        if (context.isCompact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppConfig.spacing8),
                cards[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppConfig.spacing12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _summaryCards(BuildContext context, HomeStats stats) {
    final colorScheme = Theme.of(context).colorScheme;
    final vertical = context.isTablet;
    return [
      SummaryCard(
        icon: Icons.pending_actions,
        value: stats.pendingOrdersCount.toString(),
        label: 'Pending Orders',
        containerColor: colorScheme.errorContainer,
        contentColor: colorScheme.onErrorContainer,
        vertical: vertical,
        onTap: () => context
            .read<MainShellState>()
            .switchToOrdersTab(filter: FilterPreset.allPending()),
      ),
      SummaryCard(
        icon: Icons.people_outline,
        value: stats.customersWithPendingOrdersCount.toString(),
        label: 'Customers Pending',
        containerColor: colorScheme.tertiaryContainer,
        contentColor: colorScheme.onTertiaryContainer,
        vertical: vertical,
        onTap: () => context
            .read<MainShellState>()
            .switchToCustomersTab(filter: CustomerFilterPreset.pending()),
      ),
      SummaryCard(
        icon: Icons.currency_rupee,
        value: '₹${stats.doneUnpaidAmount}',
        label: 'Done but Unpaid',
        containerColor: colorScheme.secondaryContainer,
        contentColor: colorScheme.onSecondaryContainer,
        vertical: vertical,
        onTap: () => context
            .read<MainShellState>()
            .switchToOrdersTab(filter: FilterPreset.doneButNotPaid()),
      ),
    ];
  }

  Widget _buildActionSection(BuildContext context) {
    final tiles = _actionTiles(context);

    // Portrait tablet has the full width — lay the four actions in one row.
    if (context.isMedium) {
      return SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppConfig.spacing16),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
    }

    // Phone (full column) and landscape tablet (narrow left pane) both use a
    // 2-column grid. Slightly wider tiles on tablet so they aren't too tall.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppConfig.spacing16,
      crossAxisSpacing: AppConfig.spacing16,
      childAspectRatio: context.isExpanded ? 1.6 : 1.0,
      children: tiles,
    );
  }

  List<Widget> _actionTiles(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      HomeActionTile(
        icon: Icons.note_add,
        title: 'Create Order',
        containerColor: colorScheme.primaryContainer,
        contentColor: colorScheme.onPrimaryContainer,
        onTap: () =>
            Navigator.pushNamed(context, AppConstants.orderCreatorRoute),
      ),
      HomeActionTile(
        icon: Icons.person_add,
        title: 'Create Customer',
        containerColor: colorScheme.secondaryContainer,
        contentColor: colorScheme.onSecondaryContainer,
        onTap: () =>
            Navigator.pushNamed(context, AppConstants.customerFormRoute),
      ),
      HomeActionTile(
        icon: Icons.analytics_outlined,
        title: 'Business Analysis',
        containerColor: colorScheme.tertiaryContainer,
        contentColor: colorScheme.onTertiaryContainer,
        onTap: () =>
            Navigator.pushNamed(context, AppConstants.businessAnalysisRoute),
      ),
      HomeActionTile(
        icon: Icons.auto_awesome,
        title: 'AI Assistant',
        containerColor: colorScheme.primaryContainer,
        contentColor: colorScheme.onPrimaryContainer,
        onTap: () =>
            Navigator.pushNamed(context, AppConstants.aiAssistantRoute),
      ),
    ];
  }

  Widget _buildNeedsAttention(BuildContext context) {
    final orders = context.watch<OrderState>().orders;
    final customers = context.watch<CustomerState>().customers;
    final byId = {for (final c in customers) c.id: c};

    return NeedsAttentionPanel(
      orders: orders,
      customerName: (id) => byId[id]?.name ?? 'Customer',
      onTapOrder: (order) {
        final customer = byId[order.customerId];
        if (customer == null) return;
        Navigator.pushNamed(
          context,
          AppConstants.orderDetailRoute,
          arguments: {'order': order, 'customer': customer},
        );
      },
    );
  }

  Widget _buildOverflowMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'settings') {
          Navigator.pushNamed(context, AppConstants.settingsRoute);
        } else if (value == 'backup') {
          Navigator.pushNamed(context, AppConstants.backupSettingsRoute);
        } else if (value == 'developer') {
          Navigator.pushNamed(context, AppConstants.developerRoute);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'backup',
          child: ListTile(
            leading: Icon(Icons.cloud_sync),
            title: Text('Backup & Restore'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'developer',
          child: ListTile(
            leading: Icon(Icons.code),
            title: Text('Developer'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

