import 'package:flutter/material.dart';
import '../main.dart';

mixin UnfocusOnNavigationBackMixin<T extends StatefulWidget> on State<T>
    implements RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}

