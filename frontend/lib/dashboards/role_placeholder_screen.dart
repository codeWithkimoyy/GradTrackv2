import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';

/// Role-gated placeholder used when a route has no dedicated screen yet.
/// Self-contained on purpose: it must not depend on either role's dashboard
/// components (see `dashboards/{admin,alumni}/`).
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
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.construction_outlined,
                        color: AppColors.primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .60),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            sliver: SliverList.list(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.bisuBlue700.withValues(alpha: .10),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: AppColors.bisuBlue700, size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Workspace ready',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('$title is protected by the signed-in user role.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
