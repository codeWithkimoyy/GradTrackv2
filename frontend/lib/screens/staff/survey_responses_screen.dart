import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart'
    show
        UserModel,
        UserRole,
        graduationBatchInfo,
        graduationBatchKey,
        parseApiDate;
import '../../providers/auth_providers.dart';
import '../../providers/role_providers.dart';
import '../../services/survey_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/batch_filter_widgets.dart';

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

/// Staff view of the alumni answers to one survey. Shows who answered,
/// when they submitted, and every question/answer pair for each respondent.
class SurveyResponsesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> survey;

  const SurveyResponsesScreen({super.key, required this.survey});

  @override
  ConsumerState<SurveyResponsesScreen> createState() =>
      _SurveyResponsesScreenState();
}

class _SurveyResponsesScreenState
    extends ConsumerState<SurveyResponsesScreen> {
  late final Map<String, String> _questionTexts;

  /// Selected graduation-batch filter key (`null` shows every batch).
  String? _selectedBatch;
  String _searchQuery = '';
  String? _employmentFilter;
  String? _relevanceFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _showArchived = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _questionTexts = _decodeQuestions();
  }

  Map<String, String> _decodeQuestions() {
    final data = widget.survey;
    final map = <String, String>{};
    // try detailed first
    final detailed = data['questionsDetailed'];
    Iterable rawList = [];
    if (detailed is List && detailed.isNotEmpty) rawList = detailed;
    else if (data['questions'] is List) rawList = data['questions'];
    for (final e in rawList) {
      if (e is! Map) continue;
      final m = e.map((k, v) => MapEntry(k.toString(), v));
      map[(m['id'] ?? '').toString()] = m['text']?.toString() ?? m['question_text']?.toString() ?? '';
    }
    return map;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (picked != null) setState(() => isFrom ? _dateFrom = picked : _dateTo = picked);
  }

  Future<void> _export(String format) async {
    final surveyId = widget.survey['id']?.toString() ?? '';
    try {
      final csv = await ref.read(surveyServiceProvider).exportCsv(surveyId);
      if (!mounted) return;
      final name = 'survey_${surveyId}_export.csv';
      // simple preview dialog with copy
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: Text('Export $format', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(width: double.maxFinite, height: 320, child: SingleChildScrollView(child: SelectableText(csv.isEmpty ? 'No data.' : csv.substring(0, csv.length > 5000 ? 5000 : csv.length), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')))),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Close')),
          FilledButton(onPressed: (){
            // copy to clipboard via SnackBar hint
            Navigator.pop(c);
            showAppSnackBar(context, 'Export ready: ${csv.split('\r\n').length -1} rows. CSV copied to preview - use backend /export endpoint for full file.', backgroundColor: AppColors.success);
          }, child: const Text('Done')),
        ],
      ));
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Export failed: $e', backgroundColor: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.survey;
    final surveyId = data['id']?.toString() ?? '';
    final responsesAsync = ref.watch(surveyResponsesProvider(surveyId));
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
        data: (responses) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final hintColor =
              isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
          if (responses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64,
                        color: (isDark
                                ? AppColors.tealLight
                                : AppColors.primaryBlue)
                            .withValues(alpha: .5)),
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
          final byUid = <String, UserModel>{
            for (final u in users) u.uid: u,
          };
          // CS scope: hide responses from alumni known to be outside the
          // focus program. Unknown owners are kept.
          final nonCsUids = <String>{
            for (final u in users)
              if (!AppStrings.isFocusCourse(u.course)) u.uid,
          };
          bool isVisible(Map<String, dynamic> response) =>
              !nonCsUids.contains(response['userId']?.toString());
          final nameOf = <String, String>{
            for (final u in users) u.uid: u.fullName.isEmpty ? u.uid : u.fullName,
          };
          String batchKeyOf(Map<String, dynamic> response) {
            final user = byUid[response['userId']?.toString()];
            if (user == null) return '';
            return graduationBatchKey(
              academicYearGraduated: user.academicYearGraduated,
              graduationYear: user.graduationYear,
            );
          }

          var sorted = [...responses.where(isVisible)]..sort((a, b) {
              final at = parseApiDate(a['completedAt']);
              final bt = parseApiDate(b['completedAt']);
              final an = at?.millisecondsSinceEpoch ?? 0;
              final bn = bt?.millisecondsSinceEpoch ?? 0;
              return bn.compareTo(an);
            });
          // apply dashboard filters
          sorted = sorted.where((r){
            if(!_showArchived && (r['isArchived']==true || r['is_archived']==1)) return false;
            if(_showArchived && !(r['isArchived']==true || r['is_archived']==1)) return false;
            if(_searchQuery.isNotEmpty){
              final name=(r['respondentName']?.toString() ?? nameOf[r['userId']?.toString()] ?? '').toLowerCase();
              final ans=(r['answers']?.toString() ?? '').toLowerCase();
              if(!name.contains(_searchQuery) && !ans.contains(_searchQuery)) return false;
            }
            final user=byUid[r['userId']?.toString()];
            if(_employmentFilter!=null && user!=null){
              if(user.employmentStatus.name != _employmentFilter) return false;
            }
            if(_relevanceFilter!=null){
              final ansMap = r['answers'] is Map ? Map<String,dynamic>.from(r['answers']) : {};
              final vals = ansMap.values.join(' ').toLowerCase();
              if(_relevanceFilter=='yes' && !(vals.contains('directly related') || vals.contains('somewhat related'))) return false;
              if(_relevanceFilter=='no' && !vals.contains('not related')) return false;
            }
            if(_dateFrom!=null){
              final d=parseApiDate(r['completedAt']);
              if(d!=null && d.isBefore(DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day))) return false;
            }
            if(_dateTo!=null){
              final d=parseApiDate(r['completedAt']);
              if(d!=null && d.isAfter(DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23,59,59))) return false;
            }
            return true;
          }).toList();
          if (sorted.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64,
                        color: (isDark
                                ? AppColors.tealLight
                                : AppColors.primaryBlue)
                            .withValues(alpha: .5)),
                    const SizedBox(height: 14),
                    const Text('No responses yet.'),
                    const SizedBox(height: 6),
                    Text(
                      'Answers from ${AppStrings.focusCourse} alumni will '
                      'appear here once they submit the survey.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          // Group responses by graduation batch (newest batches first,
          // unspecified last) so staff read results per cohort.
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final response in sorted) {
            groups.putIfAbsent(batchKeyOf(response), () => []).add(response);
          }
          final orderedKeys = groups.keys.toList()
            ..sort((a, b) {
              final (aYear, _) = graduationBatchInfo(a);
              final (bYear, _) = graduationBatchInfo(b);
              if (aYear == null && bYear == null) return a.compareTo(b);
              if (aYear == null) return 1;
              if (bYear == null) return -1;
              return bYear.compareTo(aYear);
            });
          final visibleKeys = _selectedBatch == null
              ? orderedKeys
              : orderedKeys.where((k) => k == _selectedBatch).toList();

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
                            style: TextStyle(color: hintColor)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.how_to_reg_rounded,
                              size: 18, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            '${sorted.length} response${sorted.length == 1 ? '' : 's'} · '
                            '${_questionTexts.length} question${_questionTexts.length == 1 ? '' : 's'} · '
                            '${AppStrings.focusCourse}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Filters, search, export, summary
              FutureBuilder<Map<String,dynamic>>(
                future: ref.read(surveyServiceProvider).fetchSummary(surveyId).catchError((_)=> <String,dynamic>{}),
                builder: (context, snap) {
                  final total = snap.data?['totalSubmissions']?.toString() ?? '${sorted.length}';
                  final qs = (snap.data?['questions'] as List?) ?? [];
                  if (qs.isEmpty) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        Row(children:[const Icon(Icons.insights_outlined, size:16, color: AppColors.primaryBlue), const SizedBox(width:6), Text('Summary  •  $total submissions', style: const TextStyle(fontWeight: FontWeight.w700, fontSize:12))]),
                        const SizedBox(height:8),
                        ...qs.take(3).map((q){
                          final opts = (q['options'] as List?) ?? [];
                          return Padding(padding: const EdgeInsets.only(bottom:6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                            Text(q['questionText']?.toString() ?? '', maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize:11, fontWeight: FontWeight.w600)),
                            const SizedBox(height:4),
                            ...opts.take(3).map((o)=> Row(children:[Expanded(child: Text(o['text']?.toString()??'', style: const TextStyle(fontSize:10), maxLines:1, overflow: TextOverflow.ellipsis)), Text('${o['count']} • ${o['percent']}%', style: const TextStyle(fontSize:10, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)) ])),
                            if((q['otherAnswers'] as List?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top:2), child: Text('Other: ${(q['otherAnswers'] as List).take(2).join(", ")}', style: const TextStyle(fontSize:10, color: Colors.grey), maxLines:1, overflow: TextOverflow.ellipsis)),
                          ]));
                        }),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(hintText: 'Search alumni or answers...', prefixIcon: const Icon(Icons.search_rounded, size:18), isDense:true, suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size:16), onPressed: ()=> setState((){ _searchController.clear(); _searchQuery=''; })) : null),
                onChanged: (v)=> setState(()=> _searchQuery=v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:[
                SizedBox(width: 160, child: DropdownButtonFormField<String?>(isExpanded:true, value: _employmentFilter, decoration: const InputDecoration(labelText: 'Employment', isDense:true), items: const [DropdownMenuItem(value:null, child: Text('All employment')), DropdownMenuItem(value:'employed', child: Text('Employed')), DropdownMenuItem(value:'unemployed', child: Text('Unemployed')), DropdownMenuItem(value:'selfEmployed', child: Text('Self-employed'))], onChanged:(v)=> setState(()=> _employmentFilter=v))),
                const SizedBox(width:8),
                SizedBox(width: 160, child: DropdownButtonFormField<String?>(isExpanded:true, value: _relevanceFilter, decoration: const InputDecoration(labelText: 'CS Relevance', isDense:true), items: const [DropdownMenuItem(value:null, child: Text('All relevance')), DropdownMenuItem(value:'yes', child: Text('Related')), DropdownMenuItem(value:'no', child: Text('Not related'))], onChanged:(v)=> setState(()=> _relevanceFilter=v))),
                const SizedBox(width:8),
                OutlinedButton.icon(onPressed: ()=> _pickDate(true), icon: const Icon(Icons.calendar_today_outlined, size:14), label: Text(_dateFrom==null? 'From': DateFormat.yMMMd().format(_dateFrom!), style: const TextStyle(fontSize:11))),
                const SizedBox(width:6),
                OutlinedButton.icon(onPressed: ()=> _pickDate(false), icon: const Icon(Icons.calendar_today_outlined, size:14), label: Text(_dateTo==null? 'To': DateFormat.yMMMd().format(_dateTo!), style: const TextStyle(fontSize:11))),
                if(_dateFrom!=null || _dateTo!=null) IconButton(icon: const Icon(Icons.clear_rounded, size:16), onPressed: ()=> setState((){ _dateFrom=null; _dateTo=null; })),
              ])),
              const SizedBox(height: 8),
              Row(children:[
                Expanded(child: OutlinedButton.icon(onPressed: ()=> _export('csv'), icon: const Icon(Icons.download_rounded, size:16), label: Text('Export CSV', style: const TextStyle(fontSize:12)))),
                const SizedBox(width:8),
                Expanded(child: OutlinedButton.icon(onPressed: ()=> _export('excel'), icon: const Icon(Icons.table_view_rounded, size:16), label: Text('Export Excel', style: const TextStyle(fontSize:12)))),
                const SizedBox(width:8),
                ChoiceChip(label: Text('Archived', style: TextStyle(fontSize:11, color: _showArchived? Colors.white: AppColors.textSecondary)), selected: _showArchived, selectedColor: AppColors.primaryBlue, onSelected: (v)=> setState(()=> _showArchived=v)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    BatchFilterChip(
                      label: 'All batches',
                      count: sorted.length,
                      selected: _selectedBatch == null,
                      onTap: () => setState(() => _selectedBatch = null),
                    ),
                    for (final key in orderedKeys) ...[
                      const SizedBox(width: 8),
                      BatchFilterChip(
                        label: graduationBatchInfo(key).$2,
                        count: groups[key]!.length,
                        selected: _selectedBatch == key,
                        onTap: () => setState(() => _selectedBatch = key),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final key in visibleKeys) ...[
                BatchSectionHeader(
                  label: graduationBatchInfo(key).$2,
                  count: groups[key]!.length,
                ),
                for (final response in groups[key]!)
                  _ResponseCard(
                    name: response['respondentName']?.toString() ??
                        nameOf[response['userId']?.toString()] ??
                        'Alumni',
                    answeredAt: parseApiDate(response['completedAt']),
                    answers: response['answers'],
                    questionTexts: _questionTexts,
                    responseId: response['id']?.toString() ?? '',
                    isArchived: response['isArchived']==true || response['is_archived']==1,
                    onArchive: () async {
                      final id=response['id']?.toString() ?? '';
                      final archived = !(response['isArchived']==true || response['is_archived']==1);
                      try{ await ref.read(surveyServiceProvider).archiveResponse(id, archived); ref.invalidate(surveyResponsesProvider(response['surveyId']?.toString() ?? surveyId)); if(context.mounted) showAppSnackBar(context, archived? 'Archived.':'Unarchived.', backgroundColor: AppColors.success);}catch(e){ if(context.mounted) showAppSnackBar(context, 'Failed: $e', backgroundColor: AppColors.error); }
                    },
                    onView: (){
                      showDialog(context: context, builder:(c)=> AlertDialog(
                        title: Text(nameOf[response['userId']?.toString()] ?? 'Alumni', style: const TextStyle(fontWeight: FontWeight.w700)),
                        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                          Text('Submitted: ${response['completedAt']?.toString() ?? ''}', style: const TextStyle(fontSize:11, color: Colors.grey)),
                          const SizedBox(height:8),
                          for(final e in ((response['answers'] is Map ? (response['answers'] as Map).entries : <MapEntry<dynamic,dynamic>>[] ) as Iterable<MapEntry>)) Padding(padding: const EdgeInsets.only(bottom:8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text(_questionTexts[e.key.toString()] ?? e.key.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize:12)), const SizedBox(height:2), Text(e.value is List ? (e.value as List).join(', ') : e.value?.toString() ?? '', style: const TextStyle(fontSize:12)), if(response['answers'] is Map && (response['answers'] as Map).containsKey('${e.key}_other')) Padding(padding: const EdgeInsets.only(top:2), child: Text('Other: ${(response['answers'] as Map)['${e.key}_other']}', style: const TextStyle(fontSize:11, color: AppColors.primaryBlue, fontStyle: FontStyle.italic))) ])),
                        ])),
                        actions: [TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Close'))],
                      ));
                    },
                  ),
              ],
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
  final String responseId;
  final bool isArchived;
  final VoidCallback? onArchive;
  final VoidCallback? onView;

  const _ResponseCard({
    required this.name,
    required this.answeredAt,
    required this.answers,
    required this.questionTexts,
    this.responseId = '',
    this.isArchived = false,
    this.onArchive,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String,dynamic> map = answers is Map
        ? Map<String,dynamic>.from((answers as Map).map((k, v) => MapEntry(k.toString(), v)))
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
                if (onView != null) IconButton(tooltip: 'View details', icon: const Icon(Icons.visibility_outlined, size:18), onPressed: onView),
                if (onArchive != null) IconButton(tooltip: isArchived? 'Unarchive':'Archive', icon: Icon(isArchived? Icons.unarchive_outlined: Icons.archive_outlined, size:18, color: isArchived? AppColors.success: Colors.grey), onPressed: onArchive),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (map.isEmpty)
              const Text('No answers recorded.')
            else
              for (final entry in map.entries.where((e)=> !e.key.endsWith('_other')))
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
                          color: isDark
                              ? AppColors.surfaceDarkAlt
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.outlineCard,
                          ),
                        ),
                        child: Text(
                          entry.value is List ? (entry.value as List).join(', ') : (entry.value?.toString() ?? ''),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (map.containsKey('${entry.key}_other') && (map['${entry.key}_other']?.toString().trim().isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top:6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal:12, vertical:8),
                            decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: isDark?0.15:0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primaryBlue.withValues(alpha:0.2))),
                            child: Row(children:[ const Icon(Icons.edit_note_rounded, size:14, color: AppColors.primaryBlue), const SizedBox(width:6), Expanded(child: Text('Other: ${map['${entry.key}_other']}', style: const TextStyle(fontSize:12, color: AppColors.primaryBlue, fontStyle: FontStyle.italic))) ]),
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