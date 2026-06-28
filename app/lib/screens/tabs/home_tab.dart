import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../constants/app_constants.dart';
import '../../domain/services/order_service.dart';
import '../../domain/state/auth_controller.dart';
import '../../domain/state/order_state.dart';
import '../../domain/state/customer_state.dart';
import '../../domain/state/main_shell_state.dart';
import '../../domain/models/filter_preset.dart';
import '../../domain/models/customer_filter_preset.dart';
import '../../presentation/presentation.dart';
import '../../presentation/widgets/home_action_tile.dart';
import '../../domain/state/sync_state.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        // Home is a root tab — never show a back arrow, even if some edge case
        // briefly leaves a route beneath the shell.
        automaticallyImplyLeading: false,
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
                  WelcomeHero(userName: context.watch<AuthController>().name),
                  const SizedBox(height: AppConfig.spacing16),
                  // Permission banner self-collapses to zero when nothing is
                  // missing, so no dead space on a fully-granted device.
                  const PermissionBanner(),
                  // BackupHealthCard owns its own bottom gap when shown; when
                  // hidden it shrinks to zero, so only the single gap above
                  // remains (no dead space on a fresh/healthy account).
                  const BackupHealthCard(),
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
        const SizedBox(height: AppConfig.spacing12),
        _buildActionSection(context),
        const SizedBox(height: AppConfig.spacing16),
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
    // Read canWrite once so grid sizing and tile list stay in sync.
    final canWrite = context.select<SyncState, bool>((s) => s.canWrite);
    final tiles = _actionTiles(context, canWrite: canWrite);

    // Portrait tablet has the full width — lay the actions in one row.
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
      mainAxisSpacing: AppConfig.spacing12,
      crossAxisSpacing: AppConfig.spacing12,
      childAspectRatio: context.isExpanded ? 1.6 : 1.0,
      children: tiles,
    );
  }

  List<Widget> _actionTiles(BuildContext context, {required bool canWrite}) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      if (canWrite)
        HomeActionTile(
          icon: Icons.note_add,
          title: 'Create Order',
          containerColor: colorScheme.primaryContainer,
          contentColor: colorScheme.onPrimaryContainer,
          onTap: () =>
              Navigator.pushNamed(context, AppConstants.orderCreatorRoute),
        ),
      if (canWrite)
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
    ];
  }

  Widget _buildNeedsAttention(BuildContext context) {
    final orders = context.watch<OrderState>().orders;
    final lookup = context.watch<CustomerState>().lookup;

    return NeedsAttentionPanel(
      orders: orders,
      customerName: (id) => lookup.nameOf(id) ?? 'Customer',
      onTapOrder: (order) {
        final customer = lookup.byId(order.customerId);
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
        if (value == 'profile') {
          Navigator.pushNamed(context, AppConstants.profileRoute);
        } else if (value == 'settings') {
          Navigator.pushNamed(context, AppConstants.settingsRoute);
        } else if (value == 'backup') {
          Navigator.pushNamed(context, AppConstants.backupSettingsRoute);
        } else if (value == 'sync') {
          Navigator.pushNamed(context, AppConstants.syncSettingsRoute);
        } else if (value == 'developer') {
          Navigator.pushNamed(context, AppConstants.developerRoute);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.account_circle_outlined),
            title: Text('Profile'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
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
          value: 'sync',
          child: ListTile(
            leading: Icon(Icons.devices),
            title: Text('Multi-device Sync'),
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

