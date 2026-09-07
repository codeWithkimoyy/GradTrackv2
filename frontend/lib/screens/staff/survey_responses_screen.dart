import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/role_providers.dart';

/// Live survey responses for a specific survey. Staff (admin/coordinator)
/// may read every response; alumni only see their own via
/// `mySurveyResponsesProvider`.
final surveyResponsesProvider = StreamProvider.autoDispose
    .family<QuerySnapshot<Map<String, dynamic>>, String>((ref, surveyId) {
  return FirebaseFirestore.instance
      .collection(FirestoreCollections.surveyResponses)
      .where('surveyId', isEqualTo: surveyId)
      .snapshots();
});

/// Alumni/guest user records so staff can attach names to responses. Admins
/// read the whole users collection; coordinators are scoped to alumni/guest
/// records by the security rules, so the same filter is applied here.
final staffUsersProvider = StreamProvider.autoDispose<
    QuerySnapshot<Map<String, dynamic>>>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  final query =
      FirebaseFirestore.instance.collection(FirestoreCollections.users);
  if (role == UserRole.admin) {
    return query.snapshots();
  }
  return query.where('role', whereIn: const ['alumni', 'guest']).snapshots();
});

/// Staff view of the alumni answers to one survey. Shows who answered,
/// when they submitted, and every question/answer pair for each respondent.
class SurveyResponsesScreen extends ConsumerStatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> survey;

  const SurveyResponsesScreen({super.key, required this.survey});

  @override
  ConsumerState<SurveyResponsesScreen> createState() =>
      _SurveyResponsesScreenState();
}

class _SurveyResponsesScreenState
    extends ConsumerState<SurveyResponsesScreen> {
  late final Map<String, String> _questionTexts;

  @override
  void initState() {
    super.initState();
    _questionTexts = _decodeQuestions();
  }

  Map<String, String> _decodeQuestions() {
    final data = widget.survey.data() ?? {};
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
  Widget build(BuildContext context) {
    final data = widget.survey.data() ?? {};
    final responsesAsync = ref.watch(surveyResponsesProvider(widget.survey.id));
    ref.watch(staffUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Responses'),
      ),
      body: responsesAsync.when(
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
        data: (snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) {
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

          final users = ref.watch(staffUsersProvider).valueOrNull?.docs ?? [];
          final nameOf = <String, String>{
            for (final d in users)
              d.id: d.data()['fullName']?.toString() ?? d.id,
          };

          final sorted = [...docs]..sort((a, b) {
              final at = (a.data()['completedAt'] as Timestamp?)?.toDate();
              final bt = (b.data()['completedAt'] as Timestamp?)?.toDate();
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
                        data['title']?.toString() ?? widget.survey.id,
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
                            '${_questionTexts.length} question${_questionTexts.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final doc in sorted)
                _ResponseCard(
                  name: nameOf[doc.data()['userId']?.toString()] ?? 'Alumni',
                  answeredAt: (doc.data()['completedAt'] as Timestamp?)
                      ?.toDate(),
                  answers: doc.data()['answers'],
                  questionTexts: _questionTexts,
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
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