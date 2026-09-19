import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../services/auth_service.dart';
import '../../services/survey_service.dart';
import '../../utils/app_snack_bar.dart';

class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});
  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final surveysAsync = ref.watch(surveysProvider);
    final responsesAsync = ref.watch(mySurveyResponsesProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Tracer Surveys', style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
      body: surveysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Surveys unavailable.\n\n$e', textAlign: TextAlign.center))),
        data: (surveys) {
          // only published, active, public already filtered by backend for alumni, but double filter
          final visible = surveys.where((s) => (s['status']?.toString().toLowerCase() ?? 'published') == 'published').toList();
          if (visible.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.fact_check_outlined, size: 32, color: AppColors.primaryBlue)), const SizedBox(height: 14), Text('No surveys published yet.', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text('Check back soon for the Computer Science tracer survey.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)])));
          return responsesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Your responses could not be loaded.\n\n$e', textAlign: TextAlign.center))),
            data: (responses) {
              final myMap = {for (final r in responses) r['surveyId']?.toString() ?? '': r};
              return ListView(padding: const EdgeInsets.all(16), children: [
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15))), child: Row(children: [const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryBlue), const SizedBox(width: 8), Expanded(child: Text('Answer published surveys to help BISU track Computer Science graduate outcomes. Your responses are private.', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)))])),
                const SizedBox(height: 16),
                ...visible.map((survey) {
                  final id = survey['id']?.toString() ?? '';
                  final resp = myMap[id];
                  final isDraft = resp != null && (resp['status']?.toString() == 'draft');
                  final isSubmitted = resp != null && resp['status']?.toString() != 'draft';
                  // fetch allowUpdate to decide if can resubmit
                  final allowUpdate = survey['allowUpdate'] == true || survey['allow_update'] == 1;
                  final canAnswer = resp == null || isDraft || allowUpdate;
                  return _SurveyCard(survey: survey, response: resp, canAnswer: canAnswer, isDraft: isDraft, isSubmitted: isSubmitted, onAnswer: () => _openSurvey(survey, resp));
                }),
              ]);
            },
          );
        },
      ),
    );
  }

  Future<void> _openSurvey(Map<String,dynamic> survey, Map<String,dynamic>? existing) async {
    // fetch full detailed survey
    final id = survey['id']?.toString() ?? '';
    Map<String,dynamic> detailed = survey;
    try {
      detailed = await ref.read(surveyServiceProvider).fetchSurvey(id);
    } catch (_) {}
    final questionsDetailed = detailed['questionsDetailed'] ?? detailed['questions'] ?? survey['questions'];
    final qs = (questionsDetailed is List) ? questionsDetailed.whereType<Map>().map((e)=> Map<String,dynamic>.from(e.map((k,v)=>MapEntry(k.toString(),v)))).toList() : <Map<String,dynamic>>[];
    // also need detailed from sync if empty, fallback to legacy
    List<Map<String,dynamic>> questions = qs.isNotEmpty ? qs : _decodeQuestions(survey['questions']);
    final saved = await Navigator.push<Map<String,dynamic>>(context, MaterialPageRoute(builder: (_) => _AnswerSurveyPage(surveyId: id, title: survey['title']?.toString() ?? 'Survey', description: survey['description']?.toString(), questions: questions, existingAnswers: (existing?['answers'] as Map?)?.map((k,v)=>MapEntry('$k',v)), existingStatus: existing?['status']?.toString(), allowUpdate: detailed['allowUpdate']==true || detailed['allow_update']==1, rawSurvey: detailed)));
    if (saved == null || !mounted) return;
    // saved contains {answers, customOthers, status}
    final answers = saved['answers'];
    final customOthers = saved['customOthers'];
    final status = saved['status']?.toString() ?? 'submitted';
    try {
      await ref.read(surveyServiceProvider).submitResponse(id, answers is Map ? Map<String,dynamic>.from(answers) : {}, customOthers: customOthers is Map ? Map<String,dynamic>.from(customOthers) : null, status: status);
      ref.invalidate(mySurveyResponsesProvider);
      if (mounted) showAppSnackBar(context, status=='draft' ? 'Draft saved.' : 'Survey submitted. Thank you!', backgroundColor: AppColors.success);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not save: ${AuthService.friendlyError(e)}', backgroundColor: AppColors.error);
    }
  }

  List<Map<String,dynamic>> _decodeQuestions(Object? raw){
    if(raw is! List) return [];
    return raw.whereType<Map>().map((e){ final m=e.map((k,v)=>MapEntry(k.toString(),v)); return Map<String,dynamic>.from(m); }).toList();
  }
}

class _SurveyCard extends StatelessWidget {
  final Map<String,dynamic> survey; final Map<String,dynamic>? response; final bool canAnswer; final bool isDraft; final bool isSubmitted; final VoidCallback onAnswer;
  const _SurveyCard({required this.survey, required this.response, required this.canAnswer, required this.isDraft, required this.isSubmitted, required this.onAnswer});
  @override
  Widget build(BuildContext context){
    final isDark = Theme.of(context).brightness==Brightness.dark;
    String badge; Color c;
    if(isDraft){ badge='Draft saved'; c=AppColors.warning; }
    else if(isSubmitted){ badge='Submitted'; c=AppColors.success; }
    else { badge='Not yet answered'; c=AppColors.warning; }
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark? AppColors.cardDark: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark? AppColors.borderDark: AppColors.outlineCard, width:1.2)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      Row(children:[
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isSubmitted? AppColors.success: AppColors.primaryBlue).withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(isSubmitted? Icons.task_alt_rounded: Icons.fact_check_outlined, color: isSubmitted? AppColors.success: AppColors.primaryBlue)),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(survey['title']?.toString()??'Survey', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize:14, color: isDark?Colors.white:AppColors.primaryNavy)),
          const SizedBox(height:2),
          Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:2), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(badge, style: GoogleFonts.poppins(fontSize:10, fontWeight: FontWeight.w700, color: c))),
        ])),
      ]),
      if((survey['description']?.toString()??'').isNotEmpty)...[
        const SizedBox(height:8),
        Text(survey['description'].toString(), style: GoogleFonts.poppins(fontSize:12, color: isDark? const Color(0xFF94A3B8): AppColors.textSecondary)),
      ],
      const SizedBox(height:12),
      SizedBox(width:double.infinity, child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(backgroundColor: canAnswer? AppColors.primaryBlue: Colors.grey, foregroundColor: Colors.white),
        onPressed: canAnswer? onAnswer: null,
        icon: Icon(canAnswer? (isDraft? Icons.edit_outlined: Icons.arrow_forward_rounded) : Icons.lock_outline_rounded, size:16),
        label: Text(canAnswer? (isDraft? 'Continue Draft' : isSubmitted ? 'Update Answers' : 'Answer Survey') : 'Already submitted', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize:13)),
      )),
      if(!canAnswer) Padding(padding: const EdgeInsets.only(top:6), child: Text('You have already submitted this survey. Contact admin to allow updates.', style: GoogleFonts.poppins(fontSize:11, color: Colors.grey))),
    ]));
  }
}

class _AnswerSurveyPage extends StatefulWidget {
  final String surveyId; final String title; final String? description; final List<Map<String,dynamic>> questions; final Map<String,dynamic>? existingAnswers; final String? existingStatus; final bool allowUpdate; final Map<String,dynamic> rawSurvey;
  const _AnswerSurveyPage({required this.surveyId, required this.title, this.description, required this.questions, this.existingAnswers, this.existingStatus, this.allowUpdate=false, required this.rawSurvey});
  @override
  State<_AnswerSurveyPage> createState()=>_AnswerSurveyPageState();
}

class _AnswerSurveyPageState extends State<_AnswerSurveyPage> {
  final _formKey = GlobalKey<FormState>();
  late List<Map<String,dynamic>> _qs;
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _singleValues = {};
  final Map<String, Set<String>> _multiValues = {};
  final Map<String, TextEditingController> _otherControllers = {};
  final Map<String, TextEditingController> _numberControllers = {};
  final Map<String, DateTime?> _dateValues = {};
  int _currentPage = 0;
  static const int _pageSize = 4;

  @override
  void initState(){
    super.initState();
    _qs = widget.questions;
    // normalize types
    for(final q in _qs){
      final rawType = (q['type']?.toString() ?? q['question_type']?.toString() ?? 'short_text').toLowerCase();
      String t;
      if(rawType=='text') t='short_text';
      else if(rawType=='choice') t='single_select';
      else t=rawType;
      q['type']=t;
      final id=q['id']?.toString()??'';
      final existing = widget.existingAnswers?[id];
      // handle other custom: existing may have "_other" key
      final otherKey='${id}_other';
      final otherVal = widget.existingAnswers?[otherKey]?.toString() ?? widget.existingAnswers?['${id}_other']?.toString();
      if(otherVal!=null && otherVal.isNotEmpty){
        _otherControllers[id]=TextEditingController(text: otherVal);
      } else {
        _otherControllers[id]=TextEditingController();
      }
      if(t=='short_text' || t=='long_text'){
        _textControllers[id]=TextEditingController(text: existing?.toString()??'');
      } else if(t=='single_select' || t=='yes_no'){
        _singleValues[id]=existing?.toString()??'';
        if(_singleValues[id]=='Other' && otherVal!=null) {
          // keep Other selected
        }
      } else if(t=='multi_select'){
        if(existing is List) _multiValues[id]=existing.map((e)=>e.toString()).toSet();
        else if(existing is String && existing.isNotEmpty) _multiValues[id]={existing};
        else _multiValues[id]=<String>{};
      } else if(t=='number'){
        _numberControllers[id]=TextEditingController(text: existing?.toString()??'');
      } else if(t=='date'){
        if(existing!=null && existing.toString().isNotEmpty){
          _dateValues[id]=DateTime.tryParse(existing.toString());
        } else _dateValues[id]=null;
      }
    }
  }
  @override
  void dispose(){
    for(final c in _textControllers.values) c.dispose();
    for(final c in _otherControllers.values) c.dispose();
    for(final c in _numberControllers.values) c.dispose();
    super.dispose();
  }

  bool _isVisible(Map<String,dynamic> q){
    final pid=q['conditionalParentId']?.toString() ?? q['conditional_parent_id']?.toString();
    final trigger=q['conditionalTriggerValue']?.toString() ?? q['conditional_trigger_value']?.toString();
    if(pid==null || pid.isEmpty) return true;
    // find parent
    final parent=_qs.firstWhere((e)=>e['id']?.toString()==pid, orElse:()=>{});
    if(parent.isEmpty) return true;
    final parentType=(parent['type']?.toString()??'').toLowerCase();
    String? parentVal;
    // get parent answer
    if(parentType=='single_select' || parentType=='yes_no'){
      parentVal=_singleValues[pid];
    } else if(parentType=='multi_select'){
      final set=_multiValues[pid];
      if(set!=null && set.contains(trigger)) return true;
      return false;
    } else {
      parentVal=_textControllers[pid]?.text ?? _singleValues[pid] ?? '';
    }
    return (parentVal??'') == (trigger??'');
  }

  List<Map<String,dynamic>> get _visibleQuestions => _qs.where(_isVisible).toList();

  double get _progress{
    final visible=_visibleQuestions;
    if(visible.isEmpty) return 0;
    int answered=0;
    for(final q in visible){
      final id=q['id']?.toString()??'';
      final t=(q['type']?.toString()??'short_text');
      dynamic val;
      if(t=='short_text'||t=='long_text') val=_textControllers[id]?.text.trim();
      else if(t=='single_select'||t=='yes_no') val=_singleValues[id];
      else if(t=='multi_select') val=_multiValues[id]?.isNotEmpty == true ? 'x' : '';
      else if(t=='number') val=_numberControllers[id]?.text.trim();
      else if(t=='date') val=_dateValues[id]?.toString();
      if(val!=null && val.toString().isNotEmpty) answered++;
      // check Other needs custom text
      if((q['allowOther']==true || q['allow_other']==1) && (
        (t=='single_select' && _singleValues[id]=='Other') ||
        (t=='multi_select' && (_multiValues[id]?.contains('Other')==true))
      )){
        if((_otherControllers[id]?.text.trim().isEmpty??true)){
          // not counted as answered if Other missing text? we count as not answered for progress
          // Actually if Other selected but empty, still counted as answered but validation will fail
        }
      }
    }
    return answered / visible.length;
  }

  int _answeredCount(List<Map<String,dynamic>> visible){
    int c=0;
    for(final q in visible){
      final id=q['id']?.toString()??'';
      final t=(q['type']?.toString()??'short_text').toLowerCase();
      dynamic val;
      if(t=='short_text'||t=='long_text') val=_textControllers[id]?.text.trim();
      else if(t=='single_select'||t=='yes_no') val=_singleValues[id];
      else if(t=='multi_select') val=_multiValues[id]?.isNotEmpty==true ? 'x' : '';
      else if(t=='number') val=_numberControllers[id]?.text.trim();
      else if(t=='date') val=_dateValues[id]?.toString();
      if(val!=null && val.toString().isNotEmpty) c++;
    }
    return c;
  }

  List<String> _optionsFor(Map<String,dynamic> q){
    final opts=q['options'];
    if(opts is List) return opts.map((e)=> e is String? e: e['text']?.toString() ?? e['option_text']?.toString() ?? '').where((s)=>s.isNotEmpty).toList();
    return [];
  }

  Future<void> _pickDate(String qid) async {
    final initial=_dateValues[qid] ?? DateTime.now();
    final picked=await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1950), lastDate: DateTime(2035));
    if(picked!=null) setState(()=>_dateValues[qid]=picked);
  }

  bool _validateAndCollect({required bool isDraft}){
    if(isDraft) return true; // draft saves without strict validation
    for(final q in _visibleQuestions){
      final id=q['id']?.toString()??'';
      final req=q['isRequired']==true || q['is_required']==1 || q['required']==true;
      final type=(q['type']?.toString()??'short_text').toLowerCase();
      dynamic val;
      if(type=='short_text'||type=='long_text') val=_textControllers[id]?.text.trim();
      else if(type=='single_select'||type=='yes_no') val=_singleValues[id];
      else if(type=='multi_select') val=_multiValues[id];
      else if(type=='number') val=_numberControllers[id]?.text.trim();
      else if(type=='date') val=_dateValues[id];
      bool empty=false;
      if(type=='multi_select') empty = (val is Set && val.isEmpty) || (val is List && val.isEmpty);
      else empty = val==null || val.toString().trim().isEmpty;
      if(req && empty){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${q['text']??q['question_text']}" is required.', style: GoogleFonts.poppins()), backgroundColor: AppColors.error));
        return false;
      }
      if((q['allowOther']==true||q['allow_other']==1) && type.contains('select')){
        bool needOther=false;
        if(type=='single_select' && _singleValues[id]=='Other') needOther=true;
        if(type=='multi_select' && (_multiValues[id]?.contains('Other')==true)) needOther=true;
        if(needOther && (_otherControllers[id]?.text.trim().isEmpty??true)){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please specify for "${q['text']??q['question_text']}".', style: GoogleFonts.poppins()), backgroundColor: AppColors.error));
          return false;
        }
      }
      if(type=='short_text' || type=='long_text'){
        final limit = q['characterLimit'] ?? q['character_limit'];
        if(limit!=null && int.tryParse(limit.toString())!=null){
          final lim=int.parse(limit.toString());
          final len=_textControllers[id]?.text.length ?? 0;
          if(len>lim){
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Answer for "${q['text']??q['question_text']}" exceeds $lim characters.', style: GoogleFonts.poppins()), backgroundColor: AppColors.error));
            return false;
          }
        }
      }
      if(type=='number' && val!=null && val.toString().isNotEmpty){
        if(double.tryParse(val.toString())==null){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter a valid number for "${q['text']??q['question_text']}".', style: GoogleFonts.poppins()), backgroundColor: AppColors.error));
          return false;
        }
      }
    }
    return true;
  }

  Map<String,dynamic> _collectAnswers(){
    final map=<String,dynamic>{};
    final others=<String,dynamic>{};
    for(final q in _qs){
      final id=q['id']?.toString()??'';
      if(!_isVisible(q)) continue;
      final type=(q['type']?.toString()??'short_text').toLowerCase();
      if(type=='short_text'||type=='long_text') map[id]=_textControllers[id]?.text.trim()??'';
      else if(type=='single_select'||type=='yes_no') map[id]=_singleValues[id]??'';
      else if(type=='multi_select') map[id]=_multiValues[id]?.toList() ?? [];
      else if(type=='number') map[id]=_numberControllers[id]?.text.trim()??'';
      else if(type=='date') map[id]=_dateValues[id]?.toIso8601String().split('T').first ?? '';
      final allowOther=q['allowOther']==true || q['allow_other']==1;
      if(allowOther){
        bool need=false;
        if(type=='single_select' && _singleValues[id]=='Other') need=true;
        if(type=='multi_select' && (_multiValues[id]?.contains('Other')==true)) need=true;
        if(need){
          final txt=_otherControllers[id]?.text.trim()??'';
          if(txt.isNotEmpty){
            others[id]=txt;
            map['${id}_other']=txt;
          }
        }
      }
    }
    return {'answers':map, 'customOthers':others};
  }

  Future<void> _saveDraft() async {
    final collected=_collectAnswers();
    Navigator.pop(context, {'answers': collected['answers'], 'customOthers': collected['customOthers'], 'status':'draft'});
  }

  Future<void> _submit() async {
    if(!_validateAndCollect(isDraft:false)) return;
    final ok=await showDialog<bool>(context: context, builder:(c)=>AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Text('Submit survey?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)), content: Text('You won\'t be able to edit after submission unless the administrator allows updates. Submit now?', style: GoogleFonts.poppins(fontSize:13, color: AppColors.textSecondary)), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('Cancel', style: GoogleFonts.poppins())), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue), onPressed: ()=>Navigator.pop(c,true), child: Text('Submit', style: GoogleFonts.poppins()))]));
    if(ok!=true) return;
    final collected=_collectAnswers();
    Navigator.pop(context, {'answers': collected['answers'], 'customOthers': collected['customOthers'], 'status':'submitted'});
  }

  Widget _buildQuestionCard(int idx, Map<String,dynamic> q){
    final id=q['id']?.toString()??'$idx';
    final text=q['text']?.toString() ?? q['question_text']?.toString() ?? 'Question ${idx+1}';
    final type=(q['type']?.toString()??'short_text').toLowerCase();
    final placeholder=q['placeholder']?.toString();
    final charLimit=q['characterLimit']?.toString() ?? q['character_limit']?.toString();
    final isRequired=q['isRequired']==true || q['is_required']==1 || q['required']==true;
    final allowOther=q['allowOther']==true || q['allow_other']==1;
    final opts=_optionsFor(q);
    final isDark=Theme.of(context).brightness==Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: isDark? AppColors.cardDark: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark? AppColors.borderDark: AppColors.outlineCard, width:1.2), boxShadow: isDark? []: const [BoxShadow(color: Color(0x0A0052CC), blurRadius: 12, offset: Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[
          Container(width:28, height:28, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('${idx+1}', style: GoogleFonts.poppins(fontSize:12, fontWeight: FontWeight.w700, color: AppColors.primaryBlue))),
          const SizedBox(width:10),
          Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize:13.5, fontWeight: FontWeight.w600, color: isDark?Colors.white:AppColors.primaryNavy))),
          if(isRequired) Container(margin: const EdgeInsets.only(left:6), padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text('*', style: GoogleFonts.poppins(fontSize:11, fontWeight: FontWeight.w700, color: AppColors.error))),
        ]),
        const SizedBox(height:12),
        if(type=='short_text') ...[
          TextFormField(controller: _textControllers[id], maxLines:1, decoration: InputDecoration(hintText: placeholder ?? 'Your answer', hintStyle: GoogleFonts.poppins(fontSize:12, color: isDark? const Color(0xFF94A3B8): AppColors.textSecondary)), onChanged: (_)=>setState((){})),
          if(charLimit!=null) ...[
            const SizedBox(height:4),
            Align(alignment: Alignment.centerRight, child: Text('${(_textControllers[id]?.text.length??0)}/${charLimit} characters', style: GoogleFonts.poppins(fontSize:10, color: ((_textControllers[id]?.text.length??0) > int.parse(charLimit) ? AppColors.error : Colors.grey)))),
          ],
        ] else if(type=='long_text') ...[
          TextFormField(controller: _textControllers[id], minLines:3, maxLines:5, decoration: InputDecoration(hintText: placeholder ?? 'Your answer', hintStyle: GoogleFonts.poppins(fontSize:12)), onChanged: (_)=>setState((){})),
          if(charLimit!=null) Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top:4), child: Text('${(_textControllers[id]?.text.length??0)}/${charLimit}', style: GoogleFonts.poppins(fontSize:10, color: ((_textControllers[id]?.text.length??0) > int.parse(charLimit) ? AppColors.error : Colors.grey))))),
        ] else if(type=='single_select') ...[
          DropdownButtonFormField<String>(isExpanded:true, value: _singleValues[id]?.isEmpty==true? null : _singleValues[id], decoration: InputDecoration(hintText: 'Select an option', hintStyle: GoogleFonts.poppins(fontSize:12), isDense:true, contentPadding: const EdgeInsets.symmetric(horizontal:12, vertical:14)), items: opts.map((o)=>DropdownMenuItem(value:o, child: Text(o, style: GoogleFonts.poppins(fontSize:13)))).toList(), onChanged: (v)=>setState(()=>_singleValues[id]=v??'')),
          if(allowOther && _singleValues[id]=='Other') ...[
            const SizedBox(height:8),
            TextFormField(controller: _otherControllers[id], decoration: InputDecoration(labelText: 'Please specify *', hintText: placeholder ?? 'Enter your job role or industry', isDense:true), onChanged: (_)=>setState((){}), validator: (v)=> (v==null||v.trim().isEmpty)?'Required when Other selected':null),
          ],
        ] else if(type=='multi_select') ...[
          // compact multi-select via FilterChips + dropdown button
          Wrap(spacing:6, runSpacing:6, children: opts.map((o){
            final selected=_multiValues[id]?.contains(o)??false;
            return FilterChip(label: Text(o, style: GoogleFonts.poppins(fontSize:11)), selected: selected, selectedColor: AppColors.primaryBlue.withOpacity(0.15), onSelected: (v){ setState((){ _multiValues[id] ??= <String>{}; if(v) _multiValues[id]!.add(o); else _multiValues[id]!.remove(o); }); });
          }).toList()),
          if(opts.isEmpty) Text('No options configured.', style: GoogleFonts.poppins(fontSize:11, color: Colors.grey)),
          if(allowOther && (_multiValues[id]?.contains('Other')==true)) ...[
            const SizedBox(height:8),
            TextFormField(controller: _otherControllers[id], decoration: InputDecoration(labelText: 'Please specify *', hintText: placeholder ?? 'Enter another skill', isDense:true)),
          ],
        ] else if(type=='yes_no') ...[
          Row(children:[
            Expanded(child: ChoiceChip(label: Text('Yes', style: GoogleFonts.poppins(fontSize:12)), selected: _singleValues[id]=='Yes', onSelected: (v)=>setState(()=>_singleValues[id]=v?'Yes':''))),
            const SizedBox(width:8),
            Expanded(child: ChoiceChip(label: Text('No', style: GoogleFonts.poppins(fontSize:12)), selected: _singleValues[id]=='No', onSelected: (v)=>setState(()=>_singleValues[id]=v?'No':''))),
          ]),
          // support custom Yes/No options if provided
          if(opts.length>=2 && !(opts.contains('Yes')||opts.contains('No'))) ...[
            const SizedBox(height:8),
            DropdownButtonFormField<String>(isExpanded:true, value: _singleValues[id]?.isEmpty==true? null: _singleValues[id], decoration: const InputDecoration(isDense:true), items: opts.map((o)=>DropdownMenuItem(value:o, child: Text(o))).toList(), onChanged: (v)=>setState(()=>_singleValues[id]=v??'')),
          ],
        ] else if(type=='number') ...[
          TextFormField(controller: _numberControllers[id], keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: InputDecoration(hintText: placeholder ?? 'Enter a number', isDense:true)),
        ] else if(type=='date') ...[
          InkWell(onTap: ()=>_pickDate(id), child: InputDecorator(decoration: const InputDecoration(isDense:true, suffixIcon: Icon(Icons.calendar_month_outlined, size:18)), child: Text(_dateValues[id]==null ? (placeholder ?? 'Select a date') : DateFormat.yMMMd().format(_dateValues[id]!), style: GoogleFonts.poppins(fontSize:13, color: _dateValues[id]==null? Colors.grey: isDark?Colors.white:AppColors.primaryNavy)))),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context){
    final visible=_visibleQuestions;
    final total=visible.length;
    final isDark=Theme.of(context).brightness==Brightness.dark;
    final paginated = total > _pageSize;
    final pageCount = (total / _pageSize).ceil();
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, total);
    final pageQuestions = paginated ? visible.sublist(start, end) : visible;
    return Scaffold(
      backgroundColor: isDark? const Color(0xFF031A48): AppColors.surfaceLight,
      appBar: AppBar(backgroundColor: isDark? const Color(0xFF031A48): AppColors.surfaceLight, foregroundColor: isDark? Colors.white: AppColors.primaryNavy, elevation:0, title: Text(widget.title, maxLines:1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
      body: Stack(children:[
        Positioned.fill(child: Image.asset('assets/images/landing.jpg', fit: BoxFit.cover, color: Colors.black.withOpacity(0.35), colorBlendMode: BlendMode.darken, errorBuilder: (_,__,___)=>const SizedBox.shrink())),
        SafeArea(child: Column(children:[
          Container(padding: const EdgeInsets.fromLTRB(16,12,16,12), decoration: BoxDecoration(color: isDark? const Color(0xCC031A48): Colors.white.withOpacity(0.92), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.12)))), child: Column(children:[
            Row(children:[Expanded(child: Text('Progress', style: GoogleFonts.poppins(fontSize:11, fontWeight: FontWeight.w600, color: isDark? Colors.white: AppColors.primaryNavy))), Text('${(_progress*100).round()}% • ${_answeredCount(visible)}/$total answered', style: GoogleFonts.poppins(fontSize:11, color: isDark? const Color(0xFF94A3B8): AppColors.textSecondary))]),
            const SizedBox(height:6),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: _progress, minHeight:6, backgroundColor: Colors.white.withOpacity(0.25), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)))),
            if(paginated) ...[
              const SizedBox(height:8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pageCount, (i){
                final selected = i == _currentPage;
                return Container(width: selected ? 22 : 8, height:8, margin: const EdgeInsets.symmetric(horizontal:3), decoration: BoxDecoration(color: selected ? Colors.white : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(4)));
              })),
            ],
          ])),
          Expanded(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(16,16,16,24), children:[
            if(widget.description!=null && widget.description!.isNotEmpty) Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom:12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineCard)), child: Text(widget.description!, style: GoogleFonts.poppins(fontSize:12, color: AppColors.textSecondary))),
            if(visible.isEmpty) Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Text('No questions available.', style: GoogleFonts.poppins())),
            ...pageQuestions.asMap().entries.map((e){
              final globalIdx = paginated? start + e.key : e.key;
              return _buildQuestionCard(globalIdx, e.value);
            }),
            const SizedBox(height:12),
            if(paginated) Row(children:[
              Expanded(child: OutlinedButton(onPressed: _currentPage>0 ? () => setState(() => _currentPage--) : null, child: Text('Previous', style: GoogleFonts.poppins()))),
              const SizedBox(width:12),
              Expanded(child: FilledButton(onPressed: _currentPage < pageCount-1 ? () => setState(() => _currentPage++) : null, style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue), child: Text(_currentPage==pageCount-1? 'Last page': 'Next', style: GoogleFonts.poppins()))),
            ]),
            const SizedBox(height:16),
            Row(children:[
              Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(backgroundColor: Colors.white), onPressed: () async { if(!mounted) return; await _saveDraft(); }, icon: const Icon(Icons.save_outlined, size:16), label: Text('Save Draft', style: GoogleFonts.poppins(fontSize:13)))),
              const SizedBox(width:12),
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:14)), onPressed: _submit, icon: const Icon(Icons.send_rounded, size:16), label: Text('Submit Survey', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
            ]),
            const SizedBox(height:8),
            Text('Your responses help improve the Computer Science program.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize:10, color: Colors.white.withOpacity(0.7))),
          ]))),
        ])),
      ]),
    );
  }
}
