import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
  IconData? icon,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      backgroundColor: backgroundColor,
      duration: duration,
      action: action,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    ),
  );
}

void showSuccess(BuildContext context, String message) {
  showAppSnackBar(
    context,
    message,
    backgroundColor: AppColors.success,
    duration: const Duration(seconds: 3),
    icon: Icons.check_circle_outline_rounded,
  );
}

void showError(BuildContext context, String message) {
  showAppSnackBar(
    context,
    message,
    backgroundColor: AppColors.error,
    duration: const Duration(seconds: 4),
    icon: Icons.error_outline_rounded,
  );
}

void showWarning(BuildContext context, String message) {
  showAppSnackBar(
    context,
    message,
    backgroundColor: AppColors.warning,
    duration: const Duration(seconds: 3),
    icon: Icons.warning_amber_rounded,
  );
}

void showInfo(BuildContext context, String message) {
  showAppSnackBar(
    context,
    message,
    backgroundColor: AppColors.info,
    duration: const Duration(seconds: 3),
    icon: Icons.info_outline_rounded,
  );
}
