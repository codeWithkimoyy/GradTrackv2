import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/role_providers.dart';
import '../../services/survey_service.dart';

/// Live survey responses for a specific survey. Staff (admin)
/// may read every response; alumni only see their own via
/// `mySurveyResponsesProvider`.
final surveyResponsesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, surveyId) {
  return ref.watch(surveyServiceProvider).watchResponses(surveyId);
});

/// Alumni user records so staff can attach names to responses. Admins read
/// the whole directory; non-admins are scoped to alumni records.
final staffUsersProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return ref.watch(userRepositoryProvider).watchUsers(
      role: role == UserRole.admin ? null : 'alumni', limit: 500);
});

/// Staff view of a survey: individual responses in one tab, and an
/// automatically generated report (response counts, per-question analytics
/// and batch breakdown) in the other.
class SurveyResponsesScreen extends ConsumerWidget {
  final Map<String, dynamic> survey;

  const SurveyResponsesScreen({super.key, required this.survey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyId = survey['id']?.toString() ?? '';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Survey Responses'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(surveyResponsesProvider(surveyId));
                ref.invalidate(surveyReportProvider(surveyId));
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Responses'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ResponsesView(survey: survey),
            _ReportsView(survey: survey),
          ],
        ),
      ),
    );
  }
}

class _ResponsesView extends ConsumerWidget {
  final Map<String, dynamic> survey;

  const _ResponsesView({required this.survey});

  Map<String, String> _decodeQuestions(Map<String, dynamic> data) {
    final map = <String, String>{};
    final raw = data['questions'];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final m = e.map((k, v) => MapEntry(k.toString(), v));
        map[(m['id'] ?? '').toString()] = m['text']?.toString() ?? '';
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = survey;
    final surveyId = data['id']?.toString() ?? '';
    final responsesAsync = ref.watch(surveyResponsesProvider(surveyId));
    ref.watch(staffUsersProvider);
    final questionTexts = _decodeQuestions(data);

    return responsesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Responses could not be loaded right now.\n\n$e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (responses) {
        if (responses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64,
                      color: AppColors.primaryBlue.withValues(alpha: .25)),
                  const SizedBox(height: 14),
                  const Text('No responses yet.'),
                  const SizedBox(height: 6),
                  Text(
                    'Alumni answers will appear here once they submit the survey.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        final users = ref.watch(staffUsersProvider).valueOrNull ?? [];
        final nameOf = <String, String>{
          for (final u in users) u.uid: u.fullName.isEmpty ? u.uid : u.fullName,
        };

        final sorted = [...responses]..sort((a, b) {
            final at = parseApiDate(a['completedAt']);
            final bt = parseApiDate(b['completedAt']);
            final an = at?.millisecondsSinceEpoch ?? 0;
            final bn = bt?.millisecondsSinceEpoch ?? 0;
            return bn.compareTo(an);
          });

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title']?.toString() ?? surveyId,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    if (data['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(data['description'].toString(),
                          style: const TextStyle(color: Colors.black54)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.how_to_reg_rounded,
                            size: 18, color: AppColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          '${sorted.length} response${sorted.length == 1 ? '' : 's'} · '
                          '${questionTexts.length} question${questionTexts.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final response in sorted)
              _ResponseCard(
                name: response['respondentName']?.toString() ??
                    nameOf[response['userId']?.toString()] ??
                    'Alumni',
                answeredAt: parseApiDate(response['completedAt']),
                answers: response['answers'],
                questionTexts: questionTexts,
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _ReportsView extends ConsumerWidget {
  final Map<String, dynamic> survey;

  const _ReportsView({required this.survey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyId = survey['id']?.toString() ?? '';
    final reportAsync = ref.watch(surveyReportProvider(surveyId));

    return reportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'The report could not be generated right now.\n\n$e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (report) {
        final totalResponses =
            (report['totalResponses'] as num?)?.toInt() ?? 0;
        if (totalResponses == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart_outlined,
                      size: 64,
                      color: AppColors.primaryBlue.withValues(alpha: .25)),
                  const SizedBox(height: 14),
                  const Text('No responses to report on yet.'),
                  const SizedBox(height: 6),
                  Text(
                    'Once alumni answer this survey, counts, per-question '
                    'analytics and batch breakdowns appear here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        final questions = ((report['questions'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final batchBreakdown = ((report['batchBreakdown'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _ReportSummaryCard(report: report),
            const SizedBox(height: AppSpacing.md),
            if (batchBreakdown.isNotEmpty)
              _BatchBreakdownCard(batches: batchBreakdown),
            if (batchBreakdown.isNotEmpty) const SizedBox(height: AppSpacing.md),
            const Text('Question Analytics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Aggregated from ${totalResponses == 1 ? '1 response' : '$totalResponses responses'}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final q in questions) ...[
              (q['type']?.toString() == 'choice'
                  ? _ChoiceQuestionReport(question: q)
                  : _TextQuestionReport(question: q)),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ReportSummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final totalResponses = (report['totalResponses'] as num?)?.toInt() ?? 0;
    final batches =
        ((report['batchBreakdown'] as List?) ?? []).whereType<Map>();
    final questions =
        ((report['questions'] as List?) ?? []).whereType<Map>();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report['title']?.toString() ?? 'Survey report',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            if (report['description'] != null) ...[
              const SizedBox(height: 4),
              Text(report['description'].toString(),
                  style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _SummaryStat(
                  icon: Icons.how_to_reg_rounded,
                  value: '$totalResponses',
                  label: 'Responses',
                ),
                const SizedBox(width: AppSpacing.lg),
                _SummaryStat(
                  icon: Icons.groups_outlined,
                  value: '${batches.length}',
                  label: 'Batches',
                ),
                const SizedBox(width: AppSpacing.lg),
                _SummaryStat(
                  icon: Icons.quiz_outlined,
                  value: '${questions.length}',
                  label: 'Questions',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _BatchBreakdownCard extends StatelessWidget {
  final List<Map> batches;

  const _BatchBreakdownCard({required this.batches});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.groups_outlined,
                    size: 20, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('Responses by Batch',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: batches.map((b) {
                final year = b['year'];
                final count = (b['count'] as num?)?.toInt() ?? 0;
                return Chip(
                  avatar: Icon(count > 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.remove_circle_outline_rounded,
                      size: 18, color: AppColors.primaryBlue),
                  label: Text(
                    year == null ? 'No batch' : 'Batch $year · $count',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceQuestionReport extends StatelessWidget {
  final Map<String, dynamic> question;

  const _ChoiceQuestionReport({required this.question});

  @override
  Widget build(BuildContext context) {
    final options =
        ((question['options'] as List?) ?? []).whereType<Map>().toList();
    final maxCount =
        options.fold<int>(0, (m, o) {
          final c = (o['count'] as num?)?.toInt() ?? 0;
          return c > m ? c : m;
        });

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question['text']?.toString() ?? 'Question',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Text('Multiple choice',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            for (final option in options) ...[
              _OptionBar(
                value: option['value']?.toString() ?? '',
                count: (option['count'] as num?)?.toInt() ?? 0,
                percentage: (option['percentage'] as num?)?.toDouble() ?? 0,
                fraction:
                    maxCount == 0 ? 0 : ((option['count'] as num?)?.toInt() ?? 0) / maxCount,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionBar extends StatelessWidget {
  final String value;
  final int count;
  final double percentage;
  final double fraction;

  const _OptionBar({
    required this.value,
    required this.count,
    required this.percentage,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count · ${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ],
    );
  }
}

class _TextQuestionReport extends StatelessWidget {
  final Map<String, dynamic> question;

  const _TextQuestionReport({required this.question});

  @override
  Widget build(BuildContext context) {
    final responses =
        ((question['responses'] as List?) ?? []).whereType<String>().toList();
    final totalAnswered = (question['totalAnswered'] as num?)?.toInt() ?? 0;
    final more = (question['more'] as num?)?.toInt() ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question['text']?.toString() ?? 'Question',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Text('Short answer · $totalAnswered answered',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            if (responses.isEmpty)
              const Text('No written answers yet.')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: responses
                    .map((r) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(r,
                              style: const TextStyle(fontSize: 12.5)),
                        ))
                    .toList(),
              ),
            if (more > 0) ...[
              const SizedBox(height: 6),
              Text('… and $more more answers',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final String name;
  final DateTime? answeredAt;
  final Object? answers;
  final Map<String, String> questionTexts;

  const _ResponseCard({
    required this.name,
    required this.answeredAt,
    required this.answers,
    required this.questionTexts,
  });

  @override
  Widget build(BuildContext context) {
    final map = answers is Map
        ? (answers as Map).map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppColors.primaryBlue.withValues(alpha: .10),
                  child: const Icon(Icons.person_outline_rounded,
                      color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(
                        answeredAt != null
                            ? DateFormat('MMM d, yyyy · h:mm a')
                                .format(answeredAt!)
                            : 'Submitted',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (map.isEmpty)
              const Text('No answers recorded.')
            else
              for (final entry in map.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        questionTexts[entry.key] ?? 'Question ${entry.key}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          entry.value?.toString() ?? '',
                          style: const TextStyle(fontSize: 14),
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
}