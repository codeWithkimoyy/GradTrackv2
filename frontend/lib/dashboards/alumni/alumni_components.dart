// Alumni-only dashboard building blocks. This library is owned by the
// alumni dashboard; the admin dashboard has its own copy under
// dashboards/admin. Do not import admin components here.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../utils/avatar_utils.dart';

class AlumniDashboardPage extends StatelessWidget {
  const AlumniDashboardPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
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
                      color: accent.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(icon, color: accent, size: 28),
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
                          subtitle,
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
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }
}

class AlumniMetricGrid extends StatelessWidget {
  const AlumniMetricGrid({super.key, required this.metrics});

  final List<AlumniMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? (metrics.length <= 2 ? 2 : 4)
            : (constraints.maxWidth < 280 ? 1 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 126,
          ),
          itemBuilder: (context, index) => _AlumniMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class AlumniMetric {
  const AlumniMetric(this.label, this.value, this.icon, this.color, {this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _AlumniMetricCard extends StatelessWidget {
  const _AlumniMetricCard({required this.metric});

  final AlumniMetric metric;

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: metric.color.withValues(alpha: .24),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0B1F3A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(metric.icon, color: metric.color, size: 20),
              ),
              if (metric.onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: metric.color.withValues(alpha: 0.7),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                metric.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.2,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .58),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (metric.onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: metric.onTap,
          borderRadius: BorderRadius.circular(20),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }
}

class AlumniSectionCard extends StatelessWidget {
  const AlumniSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.bisuBlue700.withValues(alpha: .10),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B1F3A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.bisuBlue700, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class AlumniActionGrid extends StatelessWidget {
  const AlumniActionGrid({super.key, required this.actions});

  final List<AlumniAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 4 ? 1.6 : 1.35,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.bisuBlue700.withValues(alpha: .12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.bisuBlue700.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(action.icon,
                            color: AppColors.bisuBlue700, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AlumniAction {
  const AlumniAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

Widget alumniAvatar(UserModel user, {double radius = 25}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.bisuBlue700.withValues(alpha: .14),
    backgroundImage: user.photoUrl == null
        ? null
        : avatarProvider(user.photoUrl!),
    child: user.photoUrl == null
        ? Text(
            user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
            style: TextStyle(
              color: AppColors.bisuBlue700,
              fontWeight: FontWeight.w700,
              fontSize: radius * .72,
            ),
          )
        : null,
  );
}
