import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../presentation/presentation.dart';
import 'widgets/settings/account_card.dart';

/// Profile screen — the signed-in account (email, name) and sign-out. Moved
/// out of Settings so account management has its own home.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
