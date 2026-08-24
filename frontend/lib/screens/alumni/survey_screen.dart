import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../utils/app_snack_bar.dart';

/// Live snapshot of published surveys (newest first).
final surveysProvider = StreamProvider.autoDispose<
    QuerySnapshot<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirestoreCollections.surveys)
      .orderBy('createdAt', descending: true)
      .snapshots();
});

/// Maps surveyId -> the signed-in user's saved response document.
final mySurveyResponsesProvider = FutureProvider.autoDispose<
    Map<String, DocumentSnapshot<Map<String, dynamic>>>>((ref) async {
  final userUid = ref.watch(currentUserProfileProvider).valueOrNull?.uid;
  if (userUid == null) return {};
  final snap = await FirebaseFirestore.instance
      .collection(FirestoreCollections.surveyResponses)
      .where('userId', isEqualTo: userUid)
      .get();
  return {
    for (final d in snap.docs) (d.data()['surveyId'] as String? ?? ''): d,
  };
});

/// Alumni tracer survey center: browse published surveys, answer them and
/// review previously submitted answers. Responses are stored under the
/// signed-in user's id only.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final surveysAsync = ref.watch(surveysProvider);
    final responsesAsync = ref.watch(mySurveyResponsesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tracer Surveys')),
      body: surveysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Surveys are unavailable right now.\n\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fact_check_outlined,
                        size: 64, color: AppColors.primaryBlue),
                    SizedBox(height: 14),
                    Text('No surveys published yet.'),
                    SizedBox(height: 6),
                    Text(
                      'Check back soon for the graduate tracer survey.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return responsesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Your responses could not be loaded right now.\n\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (myMap) => ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Answer published surveys to help BISU track graduate outcomes. Your responses are private.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                ...docs.map((doc) => _SurveyCard(
                      survey: doc,
                      responseDoc: myMap[doc.id],
                      onAnswer: () => _openSurvey(doc, myMap[doc.id]),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSurvey(
    DocumentSnapshot<Map<String, dynamic>> survey,
    DocumentSnapshot<Map<String, dynamic>>? existing,
  ) async {
    final data = survey.data() ?? {};
    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _AnswerSurveyPage(
          surveyId: survey.id,
          title: data['title']?.toString() ?? 'Survey',
          description: data['description']?.toString(),
          questions: _decodeQuestions(data['questions']),
          existingAnswers:
              existing?.data()?['answers'] as Map<String, dynamic>?,
        ),
      ),
    );
    if (saved == null || !mounted) return;

    try {
      final user = ref.read(currentUserProfileProvider).valueOrNull;
      if (user == null) return;
      final responseRef = existing?.reference ??
          FirebaseFirestore.instance
              .collection(FirestoreCollections.surveyResponses)
              .doc();
      await responseRef.set({
        'userId': user.uid,
        'surveyId': survey.id,
        'answers': saved,
        'completedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showAppSnackBar(context, 'Survey submitted. Thank you!',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not save your answers: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  List<Map<String, dynamic>> _decodeQuestions(Object? raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) {
      final map = e.map((k, v) => MapEntry(k.toString(), v));
      return map;
    }).toList();
  }
}

class _SurveyCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> survey;
  final DocumentSnapshot<Map<String, dynamic>>? responseDoc;
  final VoidCallback onAnswer;

  const _SurveyCard({
    required this.survey,
    required this.responseDoc,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final data = survey.data() ?? {};
    final answered = responseDoc != null;
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
                    color: AppColors.primaryBlue.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    answered
                        ? Icons.task_alt_rounded
                        : Icons.fact_check_outlined,
                    color: answered ? AppColors.success : AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['title']?.toString() ?? survey.id,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            if (data['description'] != null) ...[
              const SizedBox(height: 8),
              Text(data['description'].toString(),
                  style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: answered
                      ? const Text('Submitted',
                          style: TextStyle(color: AppColors.success))
                      : const Text('Not yet answered',
                          style: TextStyle(color: AppColors.warning)),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAnswer,
                  icon: Icon(answered
                      ? Icons.edit_outlined
                      : Icons.arrow_forward_rounded),
                  label: Text(answered ? 'Review Answers' : 'Answer Survey'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerSurveyPage extends StatefulWidget {
  final String surveyId;
  final String title;
  final String? description;
  final List<Map<String, dynamic>> questions;
  final Map<String, dynamic>? existingAnswers;

  const _AnswerSurveyPage({
    required this.surveyId,
    required this.title,
    this.description,
    required this.questions,
    this.existingAnswers,
  });

  @override
  State<_AnswerSurveyPage> createState() => _AnswerSurveyPageState();
}

class _AnswerSurveyPageState extends State<_AnswerSurveyPage> {
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _choiceValues = {};

  @override
  void initState() {
    super.initState();
    for (final q in widget.questions) {
      final id = q['id']?.toString() ?? '';
      final type = q['type']?.toString() ?? 'text';
      if (type == 'choice') {
        _choiceValues[id] =
            widget.existingAnswers?[id]?.toString() ?? '';
      } else {
        _textControllers[id] = TextEditingController(
            text: widget.existingAnswers?[id]?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final answers = <String, dynamic>{};
    for (final q in widget.questions) {
      final id = q['id']?.toString() ?? '';
      if (q['type']?.toString() == 'choice') {
        answers[id] = _choiceValues[id];
      } else {
        answers[id] =
            _textControllers[id]?.text.trim() ?? '';
      }
    }
    if (widget.questions.isNotEmpty &&
        answers.values.every((v) => v == null || v.toString().isEmpty)) {
      showAppSnackBar(context, 'Please answer at least one question.',
          backgroundColor: AppColors.error);
      return;
    }
    Navigator.pop(context, answers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.questions.isNotEmpty)
            IconButton(
              tooltip: 'Submit',
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (widget.description != null)
            Text(widget.description!,
                style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          if (widget.questions.isEmpty)
            const Text('This survey has no questions yet.')
          else
            ...widget.questions.asMap().entries.map((entry) {
              final i = entry.key;
              final q = entry.value;
              final id = q['id']?.toString() ?? '$i';
              final text = q['text']?.toString() ?? 'Question ${i + 1}';
              final type = q['type']?.toString() ?? 'text';
              final options = (q['options'] is List)
                  ? q['options']!.whereType<String>().toList()
                  : <String>[];

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. $text',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      if (type == 'choice' && options.isNotEmpty)
                        RadioGroup<String>(
                          groupValue: _choiceValues[id],
                          onChanged: (v) =>
                              setState(() => _choiceValues[id] = v ?? ''),
                          child: Column(
                            children: [
                              for (final option in options)
                                RadioListTile<String>(
                                  title: Text(option),
                                  value: option,
                                  dense: true,
                                ),
                            ],
                          ),
                        )
                      else if (type == 'choice')
                        TextFormField(
                          decoration: const InputDecoration(
                              hintText: 'Type your answer'),
                          onChanged: (v) =>
                              setState(() => _choiceValues[id] = v),
                        )
                      else
                        TextFormField(
                          controller: _textControllers[id],
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Your answer',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit Survey'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}