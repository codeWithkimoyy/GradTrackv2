import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';

/// Shown when the signed-in account has been disabled by an administrator.
/// Security rules correctly deny all data access for disabled accounts; this
/// screen makes that state explicit instead of surfacing permission errors.
class AccountDisabledScreen extends ConsumerWidget {
  const AccountDisabledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block_rounded, size: 72, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Your account has been disabled.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please contact the Tracer Study Administrator to restore access.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                onPressed: () => ref.read(authServiceProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}