import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../config/app_config.dart';
import 'widgets/app_logo.dart';
import 'widgets/error_message_card.dart';

/// Sign-in screen. It only triggers [AuthController.signIn]; navigation into the
/// app is driven entirely by the auth gate reacting to the auth status — there
/// is no manual routing here (single entry into the shell).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing32),
            child: Consumer<AuthController>(
              builder: (context, auth, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const AppLogo(),
                    const SizedBox(height: AppConfig.spacing48),
                    Text(
                      'Welcome!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppConfig.spacing8),
                    Text(
                      'Sign in with your Google account to continue',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConfig.spacing32),
                    if (auth.errorMessage != null) ...[
                      ErrorMessageCard(message: auth.errorMessage!),
                      const SizedBox(height: AppConfig.spacing24),
                    ],
                    _GoogleSignInButton(
                      isLoading: auth.isLoading,
                      onPressed: () => context.read<AuthController>().signIn(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.login),
        label: Text(
          isLoading ? 'Signing in...' : 'Sign in with Google',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
