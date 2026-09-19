import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

/// Toggles between light and dark mode. Use [floating] for a compact glass
/// circle suited to overlaying page content (mobile).
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.floating = false});

  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(themeModeProvider.notifier);
    final icon = isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    final tooltip = isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode';

    void toggle() {
      notifier.setTheme(
        isDark ? AppThemeMode.light : AppThemeMode.dark,
      );
    }

    if (!floating) {
      return IconButton(
        tooltip: tooltip,
        onPressed: toggle,
        icon: Icon(icon, size: 22),
        color: Theme.of(context).colorScheme.onSurface,
      );
    }

    return Material(
      color: Theme.of(context)
          .colorScheme
          .surface
          .withOpacity(0.85),
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        onPressed: toggle,
        icon: Icon(icon, size: 20),
        color: Theme.of(context).colorScheme.onSurface,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}