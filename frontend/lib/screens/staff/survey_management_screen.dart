import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/survey_service.dart';
import '../../utils/app_snack_bar.dart';
import 'survey_editor_screen.dart';
import 'survey_responses_screen.dart';

class SurveyManagementScreen extends ConsumerWidget {
  const SurveyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surveysAsync = ref.watch(surveysProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text('Survey Management', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.primaryNavy)),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(surveysProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Create Survey', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const SurveyEditorScreen()));
          if (created == true) ref.invalidate(surveysProvider);
        },
      ),
      body: surveysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load surveys.\n\n$e', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppColors.textSecondary)))),
        data: (surveys) {
          if (surveys.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.fact_check_outlined, size: 36, color: AppColors.primaryBlue)),
                  const SizedBox(height: 16),
                  Text('No surveys yet', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.primaryNavy)),
                  const SizedBox(height: 6),
                  Text('Create the Computer Science tracer survey. Questions will appear automatically for alumni.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: () async {
                    final c = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const SurveyEditorScreen()));
                    if (c == true) ref.invalidate(surveysProvider);
                  }, icon: const Icon(Icons.add_rounded), label: Text('Create First Survey', style: GoogleFonts.poppins())),
                ]),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: surveys.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final s = surveys[i];
              final status = (s['status']?.toString() ?? (s['isActive'] == false ? 'draft' : 'published')).toLowerCase();
              final questions = (s['questions'] is List) ? (s['questions'] as List).length : 0;
              // try detailed count if available via include? fallback to questions length
              final targetBatch = s['targetBatchYear'] ?? s['target_batch_year'] ?? s['targetGraduationYear'];
              final opening = s['openingDate'] ?? s['opening_date'];
              final closing = s['closingDate'] ?? s['closing_date'];
              Color badgeColor;
              switch (status) {
                case 'published': badgeColor = AppColors.success; break;
                case 'closed': badgeColor = AppColors.error; break;
                default: badgeColor = AppColors.warning;
              }
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.outlineCard, width: 1.2),
                  boxShadow: isDark ? [] : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 2))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: badgeColor.withValues(alpha: 0.3))), child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor))),
                    const SizedBox(width: 8),
                    if (targetBatch != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)), child: Text('Batch $targetBatch', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryBlue))),
                    const Spacer(),
                    IconButton(visualDensity: VisualDensity.compact, tooltip: 'View responses', icon: const Icon(Icons.analytics_outlined, size: 18), onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SurveyResponsesScreen(survey: Map<String,dynamic>.from(s))));
                    }),
                    PopupMenuButton<String>(onSelected: (v) async {
                      final sid = s['id']?.toString() ?? '';
                      if (v == 'edit') {
                        final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SurveyEditorScreen(existing: Map<String,dynamic>.from(s))));
                        if (ok == true) ref.invalidate(surveysProvider);
                      } else if (v == 'duplicate') {
                        try {
                          final copy = Map<String,dynamic>.from(s);
                          copy.remove('id');
                          copy['title'] = '${s['title']} (Copy)';
                          await ref.read(surveyServiceProvider).createSurvey(copy);
                          ref.invalidate(surveysProvider);
                          if (context.mounted) showAppSnackBar(context, 'Survey duplicated.', backgroundColor: AppColors.success);
                        } catch (e) { if (context.mounted) showAppSnackBar(context, AuthService.friendlyError(e), backgroundColor: AppColors.error); }
                      } else if (v == 'publish') {
                        try { await ref.read(surveyServiceProvider).updateSurvey(sid, {'status':'published', 'isActive': true}); ref.invalidate(surveysProvider);} catch(e){ if(context.mounted) showAppSnackBar(context, AuthService.friendlyError(e), backgroundColor: AppColors.error); }
                      } else if (v == 'unpublish') {
                        try { await ref.read(surveyServiceProvider).updateSurvey(sid, {'status':'draft', 'isActive': false}); ref.invalidate(surveysProvider);} catch(e){ if(context.mounted) showAppSnackBar(context, AuthService.friendlyError(e), backgroundColor: AppColors.error); }
                      } else if (v == 'close') {
                        try { await ref.read(surveyServiceProvider).updateSurvey(sid, {'status':'closed'}); ref.invalidate(surveysProvider);} catch(e){ if(context.mounted) showAppSnackBar(context, AuthService.friendlyError(e), backgroundColor: AppColors.error); }
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Delete Survey?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)), content: Text('Delete "${s['title']}" and all its responses? This cannot be undone.', style: GoogleFonts.poppins()), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('Cancel', style: GoogleFonts.poppins())), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: ()=>Navigator.pop(c,true), child: Text('Delete', style: GoogleFonts.poppins()))]));
                        if (ok == true) {
                          try { await ref.read(surveyServiceProvider).deleteSurvey(sid); ref.invalidate(surveysProvider); if(context.mounted) showAppSnackBar(context,'Survey deleted.', backgroundColor: AppColors.success);} catch(e){ if(context.mounted) showAppSnackBar(context, AuthService.friendlyError(e), backgroundColor: AppColors.error); }
                        }
                      }
                    }, itemBuilder: (c) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'publish', child: Text('Publish')),
                      const PopupMenuItem(value: 'unpublish', child: Text('Unpublish (Draft)')),
                      const PopupMenuItem(value: 'close', child: Text('Close')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ]),
                  ]),
                  const SizedBox(height: 8),
                  Text(s['title']?.toString() ?? 'Untitled Survey', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.primaryNavy)),
                  if ((s['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(s['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _MetaChip(icon: Icons.quiz_outlined, label: '$questions questions'),
                    if (opening != null) _MetaChip(icon: Icons.event_outlined, label: 'Opens ${DateFormat.yMMMd().format(DateTime.parse(opening.toString()))}'),
                    if (closing != null) _MetaChip(icon: Icons.event_busy_outlined, label: 'Closes ${DateFormat.yMMMd().format(DateTime.parse(closing.toString()))}'),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () async { final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SurveyEditorScreen(existing: Map<String,dynamic>.from(s)))); if (ok == true) ref.invalidate(surveysProvider); }, icon: const Icon(Icons.edit_outlined, size: 16), label: Text('Edit', style: GoogleFonts.poppins(fontSize: 12)))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => SurveyResponsesScreen(survey: Map<String,dynamic>.from(s)))); }, icon: const Icon(Icons.visibility_outlined, size: 16), label: Text('Responses', style: GoogleFonts.poppins(fontSize: 12)))),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon; final String label;
  const _MetaChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? AppColors.cardDark : AppColors.surfaceLightAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? AppColors.borderDark : AppColors.outlineCard)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary), const SizedBox(width: 4), Text(label, style: GoogleFonts.poppins(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary))]));
  }
}
