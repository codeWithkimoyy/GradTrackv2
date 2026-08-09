import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/dashboard_stat_card.dart';
import '../../widgets/notification_bell.dart';

class DashboardShell extends ConsumerWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  int _selectedIndex(String location) {
    if (location.startsWith(AppRoutes.dashboardProfile) ||
        location.startsWith(AppRoutes.profile)) {
      return 4;
    }
    if (location.startsWith(AppRoutes.dashboardDocuments)) return 3;
    if (location.startsWith(AppRoutes.dashboardJobs)) return 2;
    if (location.startsWith(AppRoutes.dashboardAlumni)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _selectedIndex(location);

    void navigate(int index) {
      switch (index) {
        case 0:
          context.go(AppRoutes.dashboard);
        case 1:
          context.go(AppRoutes.dashboardAlumni);
        case 2:
          context.go(AppRoutes.dashboardJobs);
        case 3:
          context.go(AppRoutes.dashboardDocuments);
        case 4:
          context.go(AppRoutes.dashboardProfile);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        if (desktop) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _DesktopSidebar(
                    selectedIndex: currentIndex,
                    onSelected: navigate,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const _DesktopTopBar(),
                        Expanded(
                          child: ColoredBox(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(child: child),
          extendBody: true,
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .48),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260B1F3A),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: NavigationBar(
                    height: 68,
                    backgroundColor: Colors.transparent,
                    indicatorColor:
                        AppColors.primaryBlue.withValues(alpha: .13),
                    selectedIndex: currentIndex,
                    animationDuration: const Duration(milliseconds: 320),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.onlyShowSelected,
                    onDestinationSelected: navigate,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard_rounded, size: 27),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.groups_outlined),
                        selectedIcon: Icon(Icons.groups_rounded, size: 27),
                        label: 'Alumni',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.work_outline),
                        selectedIcon: Icon(Icons.work_rounded, size: 27),
                        label: 'Employment',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description_rounded, size: 27),
                        label: 'Documents',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person_rounded, size: 27),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    (Icons.groups_outlined, Icons.groups_rounded, 'Alumni'),
    (Icons.work_outline_rounded, Icons.work_rounded, 'Jobs'),
    (Icons.description_outlined, Icons.description_rounded, 'Documents'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 252,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0B1F3A) : Colors.white,
        border: Border(
          right: BorderSide(
            color: AppColors.primaryBlue.withValues(alpha: .12),
          ),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x120B1F3A), blurRadius: 24),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo_full.png', width: 58, height: 46, fit: BoxFit.contain),
              const SizedBox(width: 10),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Grad',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'Track',
                      style: TextStyle(color: AppColors.gold),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            'NAVIGATION',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .45),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Material(
                color: selected
                    ? AppColors.primaryBlue.withValues(alpha: .11)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? item.$2 : item.$1,
                          color: selected
                              ? AppColors.primaryBlue
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .62),
                        ),
                        const SizedBox(width: 13),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: selected
                                ? AppColors.primaryBlue
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (selected) ...[
                          const Spacer(),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: .12),
                  AppColors.secondaryBlue.withValues(alpha: .08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    color: AppColors.gold, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Secure BISU alumni portal',
                    style: TextStyle(fontSize: 11.5, height: 1.3),
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

class _DesktopTopBar extends ConsumerWidget {
  const _DesktopTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    final initials = _desktopInitials(user?.fullName ?? 'User');
    final photo = user?.photoUrl;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primaryBlue.withValues(alpha: .10),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Graduate Tracking System',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryBlue,
            backgroundImage: photo != null ? avatarProvider(photo) : null,
            child: photo == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              user?.fullName ?? 'GradTrack User',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _desktopInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isEmpty ? 'U' : name[0].toUpperCase();
}

class DashboardHomeTab extends ConsumerWidget {
  const DashboardHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return _buildEmptyState(
              'No profile found. Complete registration to continue.');
        }
        return _DashboardBody(user: user);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

Widget _buildErrorState(Object error) {
  final msg = error.toString();
  final isFirestore = msg.contains('Firestore') || msg.contains('firestore');
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Could not load profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            isFirestore
                ? 'Firestore connection blocked. Disable ad blocker for this site and reload.'
                : msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyState(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class DashboardAlumniTab extends ConsumerWidget {
  const DashboardAlumniTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return _buildEmptyState(
              'No profile found. Complete registration to continue.');
        }
        return _AlumniTab(user: user);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

class DashboardJobsTab extends ConsumerWidget {
  const DashboardJobsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return _buildEmptyState(
              'No profile found. Complete registration to continue.');
        }
        return _JobsTab(user: user);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

class DashboardDocumentsTab extends ConsumerWidget {
  const DashboardDocumentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return _buildEmptyState(
              'No profile found. Complete registration to continue.');
        }
        return _DocumentsTab(user: user);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

class _AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _AnimatedEntrance({required this.child, this.delayMs = 0});

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.96, end: 1.0));
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value.dy * 28),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final UserModel user;
  const _DashboardBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = UserModel.computeCompletion(user);
    final unreadCount = ref.watch(unreadCountProvider(user.uid));
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning,'
        : hour < 18
            ? 'Good Afternoon,'
            : 'Good Evening,';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            AppColors.secondaryBlue.withValues(alpha: .06),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedEntrance(
                    delayMs: 40,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              AppColors.primaryBlue.withValues(alpha: 0.1),
                          backgroundImage: user.photoUrl != null
                              ? avatarProvider(user.photoUrl)
                              : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: .56),
                                    ),
                              ),
                              Text(
                                user.fullName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.08,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        NotificationBell(userId: user.uid),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _AnimatedEntrance(
                    delayMs: 120,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E3A8A),
                            Color(0xFF3B82F6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.28),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Opacity(
                              opacity: 0.12,
                              child: Image.asset(
                                'assets/images/bisu.png',
                                width: 140,
                                height: 140,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profile Completion',
                                style: TextStyle(
                                  color: Color(0xFFD9E6FF),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${completion.round()}%',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () =>
                                        context.push(AppRoutes.editProfile),
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.22),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: const Text('Complete Now'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: completion / 100),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return LinearProgressIndicator(
                                      value: value,
                                      minHeight: 10,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation(
                                          AppColors.gold),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _AnimatedEntrance(
                delayMs: 180,
                child: Text('Overview',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final childAspectRatio = width < 430
                    ? 1.02
                    : width < 600
                        ? 1.14
                        : 1.35;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _AnimatedEntrance(
                      delayMs: 220 + index * 70,
                      child: _buildOverviewCard(
                        context,
                        index: index,
                        user: user,
                        unreadCount: unreadCount,
                      ),
                    ),
                    childCount: 4,
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _AnimatedEntrance(
                delayMs: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Actions',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Tap an icon to jump straight into your next step.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: 5,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) => _AnimatedEntrance(
                          delayMs: 420 + i * 50,
                          child: _buildQuickAction(
                            context,
                            index: i,
                            user: user,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _AnimatedEntrance(
                delayMs: 520,
                child: Text('Latest Announcements',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverList.builder(
            itemCount: 3,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 4),
              child: _AnimatedEntrance(
                delayMs: 580 + i * 90,
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: AppColors.gold),
                    ),
                    title: Text('Announcement ${i + 1}'),
                    subtitle: const Text('No announcements yet'),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 104)),
        ],
      ),
    );
  }
}

Widget _buildOverviewCard(BuildContext context,
    {required int index, required UserModel user, required int unreadCount}) {
  final cards = [
    (
      title: 'Employment Status',
      value: user.employmentStatus.label,
      icon: Icons.work_outline,
      color: AppColors.info,
      onTap: () => context.push(AppRoutes.employment),
    ),
    (
      title: 'Survey Completion',
      value: '2/3',
      icon: Icons.fact_check_outlined,
      color: AppColors.success,
      onTap: null,
    ),
    (
      title: 'Upcoming Events',
      value: '3',
      icon: Icons.event_available_outlined,
      color: AppColors.gold,
      onTap: null,
    ),
    (
      title: 'Notifications',
      value: unreadCount == 0 ? 'All read' : '$unreadCount new',
      icon: Icons.notifications_active_outlined,
      color: AppColors.warning,
      onTap: null,
    ),
  ];

  final card = cards[index];
  return DashboardStatCard(
    title: card.title,
    value: card.value,
    icon: card.icon,
    color: card.color,
    onTap: card.onTap,
  );
}

Widget _buildQuickAction(BuildContext context,
    {required int index, required UserModel user}) {
  final actions = [
    (
      icon: Icons.add_business_outlined,
      label: 'Log Employment',
      onTap: () => context.push(AppRoutes.addEmployment),
    ),
    (
      icon: Icons.upload_file,
      label: 'Upload Resume',
      onTap: () => context.push(AppRoutes.resume),
    ),
    (
      icon: Icons.badge_outlined,
      label: 'Add Certificate',
      onTap: () => context.push(AppRoutes.certificates),
    ),
    (
      icon: Icons.poll_outlined,
      label: 'Tracer Survey',
      onTap: () => showAppSnackBar(context, 'Coming soon',
          duration: const Duration(seconds: 2)),
    ),
    (
      icon: Icons.edit_outlined,
      label: 'Edit Profile',
      onTap: () => context.push(AppRoutes.editProfile),
    ),
  ];

  final action = actions[index];
  return _QuickAction(
    icon: action.icon,
    label: action.label,
    onTap: action.onTap,
  );
}

class _DocumentsTab extends StatelessWidget {
  final UserModel user;
  const _DocumentsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text('Documents',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Store and manage your resume and certificates from one place.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ActionCard(
          icon: Icons.upload_file,
          title: 'Resume',
          subtitle: 'Keep your professional profile ready for opportunities.',
          buttonLabel: 'Manage Resume',
          onTap: () => context.push(AppRoutes.resume),
        ),
        _ActionCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Certificates',
          subtitle: 'Upload and review your verified credentials.',
          buttonLabel: 'View Certificates',
          onTap: () => context.push(AppRoutes.certificates),
        ),
      ],
    );
  }
}

class _JobsTab extends StatelessWidget {
  final UserModel user;
  const _JobsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text('Employment',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'View your career history, milestones, and add new work records.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Work Tracker',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                Text('Current status: ${user.employmentStatus.label}'),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => context.push(AppRoutes.employment),
                  child: const Text('Open Employment History'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Icon(Icons.work_outline,
              size: 108, color: AppColors.primaryBlue.withValues(alpha: 0.15)),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _AlumniTab extends StatelessWidget {
  final UserModel user;
  const _AlumniTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text('Alumni Community',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Connect with fellow BISU alumni and access member resources.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: AppSpacing.lg),
        _InfoPanel(
          title: 'Your Alumni Record',
          content: [
            'Name: ${user.fullName}',
            'Course: ${user.course ?? 'Not set'}',
            'Graduation Year: ${user.graduationYear?.toString() ?? 'Not set'}',
            'Status: ${user.employmentStatus.label}',
          ],
        ),
        _ActionCard(
          icon: Icons.person_outline,
          title: 'Update Profile',
          subtitle: 'Keep your alumni record accurate and complete.',
          buttonLabel: 'Edit Profile',
          onTap: () => context.push(AppRoutes.editProfile),
        ),
        _ActionCard(
          icon: Icons.upload_file,
          title: 'Share Resume',
          subtitle: 'Let employers review your latest resume.',
          buttonLabel: 'Upload Resume',
          onTap: () => context.push(AppRoutes.resume),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<String> content;
  const _InfoPanel({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            ...content.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(line, style: const TextStyle(fontSize: 14)),
                )),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onTap, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .90),
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: .13),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100B1F3A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryBlue.withValues(alpha: .18),
                        AppColors.secondaryBlue.withValues(alpha: .12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
