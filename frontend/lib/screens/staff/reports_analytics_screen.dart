import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../analytics/analytics_screen.dart';
import 'reports_screen.dart';

/// Combined admin page for institutional reports and system analytics,
/// reached from the sidebar "Reports & Analytics" entry. Reuses the
/// existing screens as tabs so behavior is unchanged.
class ReportsAnalyticsScreen extends StatelessWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        isDark ? AppColors.tealLight : AppColors.primaryBlue;
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Reports & Analytics',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            labelColor: activeColor,
            unselectedLabelColor: inactiveColor,
            indicatorColor: activeColor,
            tabs: const [
              Tab(text: 'Reports', icon: Icon(Icons.assessment_outlined)),
              Tab(text: 'Analytics', icon: Icon(Icons.insights_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ReportsScreen(hideAppBar: true),
            AnalyticsScreen(adminMode: true, hideAppBar: true),
          ],
        ),
      ),
    );
  }
}
