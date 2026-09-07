import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../utils/app_snack_bar.dart';

/// A survey question currently being edited by staff.
class _QuestionDraft {
  _QuestionDraft({required this.id, this.type = 'text'});

  final String id;
  String type;
  final TextEditingController text = TextEditingController();
  final List<TextEditingController> options = [];
  final TextEditingController newOption = TextEditingController();

  void addOption([String value = '']) =>
      options.add(TextEditingController(text: value));

  void dispose() {
    text.dispose();
    for (final c in options) {
      c.dispose();
    }
    newOption.dispose();
  }
}

/// Staff editor for a graduate tracer survey. Besides the metadata fields it
/// lets the coordinator/admin build the list of questions (short answer or
/// multiple choice) that alumni answer from the "Tracer Surveys" screen.
class SurveyEditorScreen extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? existing;

  const SurveyEditorScreen({super.key, this.existing});

  @override
  State<SurveyEditorScreen> createState() => _SurveyEditorScreenState();
}

class _SurveyEditorScreenState extends State<SurveyEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _visibility = 'public';
  final List<_QuestionDraft> _questions = [];
  int _idCounter = 1;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data() ?? {};
    _titleController.text = data['title']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _visibility = data['visibility']?.toString() ?? 'public';

    final raw = data['questions'];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final m = e.map((k, v) => MapEntry(k.toString(), v));
        final q = _QuestionDraft(
          id: (m['id'] ?? 'q$_idCounter').toString(),
          type: m['type']?.toString() == 'choice' ? 'choice' : 'text',
        );
        q.text.text = m['text']?.toString() ?? '';
        final options = m['options'];
        if (options is List) {
          for (final o in options) {
            q.options.add(TextEditingController(text: o.toString()));
          }
        }
        _idCounter++;
        _questions.add(q);
      }
    }
    if (_questions.isEmpty) {
      _questions.add(_QuestionDraft(id: 'q${_idCounter++}'));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionDraft(id: 'q${_idCounter++}')));
  }

  void _removeQuestion(_QuestionDraft q) {
    setState(() => _questions.remove(q));
    WidgetsBinding.instance.addPostFrameCallback((_) => q.dispose());
  }

  void _addOption(_QuestionDraft q) {
    final value = q.newOption.text.trim();
    if (value.isEmpty) {
      showAppSnackBar(context, 'Type an option first.',
          backgroundColor: AppColors.error);
      return;
    }
    setState(() {
      q.addOption(value);
      q.newOption.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      showAppSnackBar(context, 'Add at least one question.',
          backgroundColor: AppColors.error);
      return;
    }

    final questionsData = <Map<String, dynamic>>[];
    for (final q in _questions) {
      final text = q.text.text.trim();
      if (text.isEmpty) {
        showAppSnackBar(context, 'Every question needs a text.',
            backgroundColor: AppColors.error);
        return;
      }
      final map = <String, dynamic>{
        'id': q.id,
        'text': text,
        'type': q.type,
      };
      if (q.type == 'choice') {
        final options = q.options
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (options.isEmpty) {
          showAppSnackBar(
              context, 'Add at least one option to every choice question.',
              backgroundColor: AppColors.error);
          return;
        }
        map['options'] = options;
      }
      questionsData.add(map);
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'visibility': _visibility,
      'questions': questionsData,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEdit) {
        await widget.existing!.reference.update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.surveys)
            .add(data);
      }
      if (mounted) {
        showAppSnackBar(context, 'Survey saved successfully.',
            backgroundColor: AppColors.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Save failed: $e',
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildQuestionCard(int index, _QuestionDraft q) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Question ${index + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                TextButton(
                  onPressed: () => _removeQuestion(q),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error),
                  child: const Text('Remove'),
                ),
              ],
            ),
            TextFormField(
              controller: q.text,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Question text'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: q.type,
              decoration: const InputDecoration(labelText: 'Answer type'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: 'text', child: Text('Short answer (text)')),
                DropdownMenuItem(
                    value: 'choice', child: Text('Multiple choice')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => q.type = v);
              },
            ),
            if (q.type == 'choice') ...[
              const SizedBox(height: AppSpacing.md),
              const Text('Options',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < q.options.length; i++) ...[
                Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked,
                        color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: q.options[i],
                        decoration:
                            const InputDecoration(isDense: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove option',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        q.options.removeAt(i).dispose();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: q.newOption,
                      decoration: const InputDecoration(
                          hintText: 'Type an option...', isDense: true),
                      onFieldSubmitted: (_) => _addOption(q),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add option',
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => _addOption(q),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Survey' : 'Add Survey'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Survey title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'private', child: Text('Private')),
              ],
              onChanged: (v) => setState(() => _visibility = v ?? 'public'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Questions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'These are the questions alumni will answer.',
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black54),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < _questions.length; i++)
              _buildQuestionCard(i, _questions[i]),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Question'),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Survey'),
            ),
          ],
        ),
      ),
    );
  }
}