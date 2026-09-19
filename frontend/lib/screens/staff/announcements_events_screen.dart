import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../shared/collection_list_screen.dart';

/// Combined admin page for announcements and events, reached from the
/// sidebar "Announcements & Events" entry. Reuses the existing collection
/// list screens as tabs so CRUD behavior is unchanged.
class AnnouncementsEventsScreen extends StatelessWidget {
  const AnnouncementsEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final announcements = lookupCollection('announcements')!;
    final events = lookupCollection('events')!;
    final activeColor =
        isDark ? AppColors.tealLight : AppColors.primaryBlue;
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Announcements & Events',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            labelColor: activeColor,
            unselectedLabelColor: inactiveColor,
            indicatorColor: activeColor,
            tabs: const [
              Tab(text: 'Announcements', icon: Icon(Icons.campaign_outlined)),
              Tab(text: 'Events', icon: Icon(Icons.event_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CollectionListScreen(content: announcements, hideAppBar: true),
            CollectionListScreen(content: events, hideAppBar: true),
          ],
        ),
      ),
    );
  }
}
