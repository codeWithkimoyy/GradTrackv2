import 'package:flutter/material.dart';

import 'dashboard_components.dart';

class RolePlaceholderScreen extends StatelessWidget {
  const RolePlaceholderScreen({
    super.key,
    required this.title,
    String? description,
    String? message,
    this.icon = Icons.construction_outlined,
  }) : description = description ?? message ?? '';

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: title,
      subtitle: description,
      icon: icon,
      accent: const Color(0xFF2563EB),
      children: [
        DashboardSectionCard(
          title: 'Workspace ready',
          icon: Icons.check_circle_outline_rounded,
          child: Text('$title is protected by the signed-in user role.'),
        ),
      ],
    );
  }
}
