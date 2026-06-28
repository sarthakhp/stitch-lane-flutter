import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/repositories/order_repository.dart';
import '../backend/repositories/customer_repository.dart';
import '../domain/services/notification_router.dart';
import '../domain/services/order_service.dart';
import '../domain/services/customer_service.dart';
import '../domain/services/permissions/permission_prompt_coordinator.dart';
import '../domain/state/order_state.dart';
import '../domain/state/customer_state.dart';
import '../domain/state/main_shell_state.dart';
import '../domain/state/permission_controller.dart';
import '../domain/services/home_widget/home_widget_service.dart';
import '../utils/startup_orchestrator.dart';
import '../utils/startup_tracker.dart';
import 'shell/shell_tab_navigator_access.dart';
import 'shell/tab_navigator.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/customers_tab.dart';
import 'ai_assistant_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  final _ordersTabKey = GlobalKey<OrdersTabState>();
  final _customersTabKey = GlobalKey<CustomersTabState>();
  final _aiTabKey = GlobalKey<AiAssistantScreenState>();

  // One Navigator per tab so detail screens push *inside* the tab and the
  // bottom bar stays put. The observers nudge a rebuild whenever a tab's stack
  // changes, so the back-button gate (canPop) stays accurate.
  late final List<GlobalKey<NavigatorState>> _navKeys =
      List.generate(4, (_) => GlobalKey<NavigatorState>());
  late final List<NavigatorObserver> _navObservers =
      List.generate(4, (_) => _NavStackObserver(_scheduleRebuild));

  // Lazily mount Orders/Customers tabs on first navigation.
  // Home (index 0) is always considered mounted.
  final Set<int> _mountedTabs = {0};

  void _scheduleRebuild() {
    // Observer callbacks can fire mid-build (the initial route push), so defer
    // the setState to the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Lets the deep-link coordinator push into whichever tab is showing.
  NavigatorState? _resolveActiveNavigator() =>
      _navKeys[context.read<MainShellState>().selectedIndex].currentState;

  @override
  void initState() {
    super.initState();
    StartupTracker.instance.markOnce('main_shell_init_state');
    WidgetsBinding.instance.addObserver(this);
    ShellTabNavigatorAccess.register(_resolveActiveNavigator);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTracker.instance.markOnce('main_shell_first_frame');
      _loadInitialDataWhenUncovered();
      _requestPermissions();
      _processNotificationsWhenReady();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShellTabNavigatorAccess.clear(_resolveActiveNavigator);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _processNotificationsWhenReady();
      // The user may have toggled permissions in system settings while we
      // were backgrounded — re-query so the home banner updates immediately.
      context.read<PermissionController>().refresh();
    }
  }

  /// First-frame permission entry point. Loads cached state, then shows the
  /// friendly explainer once per install. Subsequent app opens just refresh
  /// state (handled in [didChangeAppLifecycleState]) and the home banner
  /// becomes the persistent nudge.
  Future<void> _requestPermissions() async {
    final controller = context.read<PermissionController>();
    await controller.init();
    if (!mounted) return;
    await PermissionPromptCoordinator.runFirstTimeIfNeeded(context, controller);
  }

  /// Waits for NotificationService to finish initializing (in background since
  /// startup), then processes any pending notification tap that launched the app.
  Future<void> _processNotificationsWhenReady() async {
    await StartupOrchestrator.instance.notificationsReady;
    if (!mounted) return;
    NotificationRouter.processPendingNotification(context);
  }

  /// Loads the dashboard's data now, unless a widget-launched screen (e.g. the
  /// order creator) is currently covering the shell — in which case we defer
  /// the load until that screen is dismissed. The shell + bottom bar are
  /// already on screen meanwhile, so a cold widget launch stays fast.
  void _loadInitialDataWhenUncovered() {
    final covered = HomeWidgetService.instance.shellCovered;
    if (!covered.value) {
      _loadInitialData();
      return;
    }
    late final VoidCallback listener;
    listener = () {
      if (covered.value) return;
      covered.removeListener(listener);
      if (mounted) _loadInitialData();
    };
    covered.addListener(listener);
  }

  Future<void> _loadInitialData() async {
    final orderState = context.read<OrderState>();
    final orderRepository = context.read<OrderRepository>();
    final customerState = context.read<CustomerState>();
    final customerRepository = context.read<CustomerRepository>();

    await Future.wait([
      if (orderState.orders.isEmpty)
        OrderService.loadOrders(orderState, orderRepository),
      if (customerState.customers.isEmpty)
        CustomerService.loadCustomers(customerState, customerRepository),
    ]);
    StartupTracker.instance.finish();
  }

  void _onDestinationSelected(int index) {
    final shellState = context.read<MainShellState>();
    // Re-tapping the current tab pops it back to its root (standard shell UX).
    if (index == shellState.selectedIndex) {
      _navKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    if (_mountedTabs.add(index)) {
      // First visit to this tab — trigger a rebuild so the real widget mounts.
      setState(() {});
    }
    shellState.switchToTab(index);
  }

  void _applyPendingFilters(MainShellState shellState) {
    final ordersTabState = _ordersTabKey.currentState;
    if (ordersTabState != null) {
      final ordersFilter = shellState.consumeOrdersFilter();
      if (ordersFilter != null) {
        ordersTabState.applyFilter(ordersFilter);
      }
    }

    final customersTabState = _customersTabKey.currentState;
    if (customersTabState != null) {
      final customersFilter = shellState.consumeCustomersFilter();
      if (customersFilter != null) {
        customersTabState.applyFilter(customersFilter);
      }
    }

    // Home-screen widget "Chat" → AI tab with the mic opening. Only consume
    // the one-shot flag once the AI tab is actually mounted, otherwise an
    // earlier build (before the tab switch lands) would clear it and the mic
    // would never open.
    final aiTabState = _aiTabKey.currentState;
    if (aiTabState != null && shellState.consumeAiVoice()) {
      aiTabState.startVoiceInput();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shellState = context.watch<MainShellState>();
    final selectedIndex = shellState.selectedIndex;
    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 600;

    // Ensure the currently-selected tab is mounted. This covers programmatic
    // switches via MainShellState.switchToOrdersTab / switchToCustomersTab that
    // don't go through _onDestinationSelected.
    _mountedTabs.add(selectedIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPendingFilters(shellState);
    });

    final body = IndexedStack(
      index: selectedIndex,
      children: [
        _tabNavigator(0, (_) => const HomeTab()),
        _mountedTabs.contains(1)
            ? _tabNavigator(1, (_) => OrdersTab(key: _ordersTabKey))
            : const SizedBox.shrink(),
        _mountedTabs.contains(2)
            ? _tabNavigator(2, (_) => CustomersTab(key: _customersTabKey))
            : const SizedBox.shrink(),
        _mountedTabs.contains(3)
            ? _tabNavigator(
                3,
                // active must track the visible tab, but the nested navigator
                // builds the root once — so derive it reactively here instead
                // of from a frozen constructor arg.
                (_) => Consumer<MainShellState>(
                  builder: (_, shell, __) => AiAssistantScreen(
                    key: _aiTabKey,
                    active: shell.selectedIndex == 3,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );

    // The read-only banner is applied app-wide by ReaderModeOverlay (in
    // MaterialApp.builder), so the shell renders its body directly.
    Widget scaffold;
    if (useNavigationRail) {
      scaffold = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              groupAlignment: 0.0,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: Text('Orders'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Customers'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: Text('Assistant'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outlined),
              selectedIcon: Icon(Icons.people),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Assistant',
            ),
          ],
        ),
      );
    }

    // Back priority: (1) pop a detail inside the active tab, (2) return to the
    // previously-visited tab, (3) let the OS pop the shell and exit the app.
    final activeNav = _navKeys[selectedIndex].currentState;
    final nestedCanPop = activeNav?.canPop() ?? false;
    return PopScope(
      canPop: !nestedCanPop && !shellState.canPopTab,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (nestedCanPop) {
          activeNav!.pop();
        } else {
          shellState.popTab();
        }
      },
      child: scaffold,
    );
  }

  Widget _tabNavigator(int index, WidgetBuilder rootBuilder) {
    return TabNavigator(
      navigatorKey: _navKeys[index],
      observers: [_navObservers[index]],
      rootBuilder: rootBuilder,
    );
  }
}

/// Rebuilds the shell whenever a tab's nested navigator stack changes, so the
/// back-button gate ([PopScope.canPop]) reflects the current depth.
class _NavStackObserver extends NavigatorObserver {
  _NavStackObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChanged();
}

