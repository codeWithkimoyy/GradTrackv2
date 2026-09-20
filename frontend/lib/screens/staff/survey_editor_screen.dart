import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/survey_service.dart';
import '../../utils/app_snack_bar.dart';

const _questionTypeLabels = {
  'short_text': 'Short written answer',
  'long_text': 'Long written answer',
  'single_select': 'Single-select dropdown',
  'multi_select': 'Multi-select dropdown',
  'yes_no': 'Yes or No',
  'number': 'Number input',
  'date': 'Date input',
};

class _QuestionDraft {
  _QuestionDraft({required this.id, this.type = 'short_text'});
  final String id;
  String type;
  final TextEditingController text = TextEditingController();
  final TextEditingController placeholder = TextEditingController();
  final TextEditingController charLimit = TextEditingController();
  bool isRequired = false;
  bool isPublished = true;
  bool allowOther = false;
  String? conditionalParentId;
  final TextEditingController conditionalTrigger = TextEditingController();
  final List<TextEditingController> options = [];
  final TextEditingController newOption = TextEditingController();

  void addOption([String value = '']) => options.add(TextEditingController(text: value));
  void dispose() {
    text.dispose(); placeholder.dispose(); charLimit.dispose();
    conditionalTrigger.dispose(); newOption.dispose();
    for (final c in options) c.dispose();
  }
  Map<String, dynamic> toJson(int order) => {
    'id': id,
    'text': text.text.trim(),
    'type': type,
    'placeholder': placeholder.text.trim().isEmpty ? null : placeholder.text.trim(),
    'characterLimit': charLimit.text.trim().isEmpty ? null : int.tryParse(charLimit.text.trim()),
    'isRequired': isRequired,
    'isPublished': isPublished,
    'sortOrder': order,
    'conditionalParentId': conditionalParentId,
    'conditionalTriggerValue': conditionalTrigger.text.trim().isEmpty ? null : conditionalTrigger.text.trim(),
    'allowOther': allowOther,
    'options': options.map((c)=>c.text.trim()).where((s)=>s.isNotEmpty).toList(),
  };
}

class SurveyEditorScreen extends ConsumerStatefulWidget {
  final Map<String,dynamic>? existing;
  const SurveyEditorScreen({super.key, this.existing});
  @override
  ConsumerState<SurveyEditorScreen> createState()=>_SurveyEditorScreenState();
}

class _SurveyEditorScreenState extends ConsumerState<SurveyEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _targetBatch;
  DateTime? _openingDate;
  DateTime? _closingDate;
  String _status = 'draft';
  bool _allowUpdate = false;
  String _visibility = 'public';
  final List<_QuestionDraft> _questions=[];
  int _idCounter=1;
  bool _saving=false;

  bool get _isEdit=>widget.existing!=null;

  @override
  void initState(){
    super.initState();
    final data=widget.existing??{};
    _titleController.text=data['title']?.toString()??'';
    _descriptionController.text=data['description']?.toString()??'';
    final tb = data['targetBatchYear'] ?? data['target_batch_year'] ?? data['targetGraduationYear'];
    _targetBatch = tb?.toString();
    final od = data['openingDate'] ?? data['opening_date'];
    final cd = data['closingDate'] ?? data['closing_date'];
    if(od!=null) _openingDate=DateTime.tryParse(od.toString());
    if(cd!=null) _closingDate=DateTime.tryParse(cd.toString());
    _status = (data['status']?.toString() ?? (data['isActive']==false ? 'draft' : 'published')).toLowerCase();
    if(!['draft','published','closed'].contains(_status)) _status='draft';
    _allowUpdate = data['allowUpdate']==true || data['allow_update']==1;
    _visibility = data['visibility']?.toString()??'public';
    final raw = data['questions'];
    // try questionsDetailed
    final detailed = data['questionsDetailed'];
    List qs = [];
    if(detailed is List && detailed.isNotEmpty) qs=detailed;
    else if(raw is List) qs=raw;
    for(final e in qs){
      if(e is! Map) continue;
      final m=e.map((k,v)=>MapEntry(k.toString(),v));
      final id=(m['id']??'q$_idCounter').toString();
      final type=_normalizeType(m['type']?.toString() ?? m['question_type']?.toString());
      final q=_QuestionDraft(id: id, type: type);
      q.text.text=m['text']?.toString() ?? m['question_text']?.toString() ?? '';
      q.placeholder.text=m['placeholder']?.toString()??'';
      q.charLimit.text=m['characterLimit']?.toString() ?? m['character_limit']?.toString() ?? '';
      q.isRequired = m['isRequired']==true || m['is_required']==1 || m['required']==true;
      q.isPublished = m['isPublished']!=false && m['is_published']!=0;
      q.allowOther = m['allowOther']==true || m['allow_other']==1;
      q.conditionalParentId=m['conditionalParentId']?.toString() ?? m['conditional_parent_id']?.toString();
      q.conditionalTrigger.text=m['conditionalTriggerValue']?.toString() ?? m['conditional_trigger_value']?.toString()??'';
      final opts=m['options'];
      if(opts is List){
        for(final o in opts){
          if(o is String) q.addOption(o);
          else if(o is Map) q.addOption(o['text']?.toString() ?? o['option_text']?.toString() ?? '');
        }
      }
      _idCounter++;
      _questions.add(q);
    }
    if(_questions.isEmpty){
      _questions.add(_QuestionDraft(id:'q${_idCounter++}', type:'single_select'));
    }
  }

  String _normalizeType(String? v){
    if(v==null) return 'short_text';
    final s=v.toLowerCase();
    if(s=='text') return 'short_text';
    if(s=='choice') return 'single_select';
    if(_questionTypeLabels.containsKey(s)) return s;
    return 'short_text';
  }

  @override
  void dispose(){
    _titleController.dispose(); _descriptionController.dispose();
    for(final q in _questions) q.dispose();
    super.dispose();
  }

  void _addQuestion(){
    setState(()=>_questions.add(_QuestionDraft(id:'q${_idCounter++}', type:'short_text')));
  }
  void _duplicateQuestion(int idx){
    final orig=_questions[idx];
    final copy=_QuestionDraft(id:'q${_idCounter++}', type: orig.type);
    copy.text.text=orig.text.text;
    copy.placeholder.text=orig.placeholder.text;
    copy.charLimit.text=orig.charLimit.text;
    copy.isRequired=orig.isRequired;
    copy.isPublished=orig.isPublished;
    copy.allowOther=orig.allowOther;
    copy.conditionalParentId=orig.conditionalParentId;
    copy.conditionalTrigger.text=orig.conditionalTrigger.text;
    for(final o in orig.options) copy.addOption(o.text);
    setState(()=>_questions.insert(idx+1, copy));
  }
  Future<void> _removeQuestion(int idx) async {
    final q=_questions[idx];
    final ok=await showDialog<bool>(context: context, builder:(c)=>AlertDialog(title: Text('Delete question?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)), content: Text('Delete "${q.text.text.isEmpty?"Question ${idx+1}":q.text.text}"?', style: GoogleFonts.poppins()), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('Cancel', style: GoogleFonts.poppins())), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: ()=>Navigator.pop(c,true), child: Text('Delete', style: GoogleFonts.poppins()))]));
    if(ok!=true) return;
    setState(()=>_questions.removeAt(idx));
    q.dispose();
  }

  void _addOption(_QuestionDraft q){
    final v=q.newOption.text.trim();
    if(v.isEmpty){ showAppSnackBar(context,'Type an option first.', backgroundColor: AppColors.error); return; }
    if(q.options.any((c)=>c.text.trim().toLowerCase()==v.toLowerCase())){ showAppSnackBar(context,'Duplicate choice not allowed.', backgroundColor: AppColors.error); return; }
    setState((){ q.addOption(v); q.newOption.clear(); });
  }

  Future<void> _pickDate(bool isOpening) async {
    final initial = isOpening ? (_openingDate ?? DateTime.now()) : (_closingDate ?? DateTime.now().add(const Duration(days: 30)));
    final picked=await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if(picked==null) return;
    setState(()=> isOpening ? _openingDate=picked : _closingDate=picked);
  }

  Future<void> _save() async {
    if(!_formKey.currentState!.validate()) return;
    if(_openingDate!=null && _closingDate!=null && _openingDate!.isAfter(_closingDate!)){ showAppSnackBar(context,'Opening date must be before closing date.', backgroundColor: AppColors.error); return; }
    if(_questions.isEmpty){ showAppSnackBar(context,'Add at least one question.', backgroundColor: AppColors.error); return; }
    final questionsData=<Map<String,dynamic>>[];
    final seenIds=<String>{};
    for(int i=0;i<_questions.length;i++){
      final q=_questions[i];
      final text=q.text.text.trim();
      if(text.isEmpty){ showAppSnackBar(context,'Question ${i+1}: text is required.', backgroundColor: AppColors.error); return; }
      if(seenIds.contains(q.id)){ showAppSnackBar(context,'Duplicate question id.', backgroundColor: AppColors.error); return; }
      seenIds.add(q.id);
      if((q.type=='single_select'||q.type=='multi_select')){
        final opts=q.options.map((c)=>c.text.trim()).where((s)=>s.isNotEmpty).toList();
        if(opts.isEmpty){ showAppSnackBar(context,'Question ${i+1}: add at least one option.', backgroundColor: AppColors.error); return; }
        final uniq=opts.map((e)=>e.toLowerCase()).toSet();
        if(uniq.length!=opts.length){ showAppSnackBar(context,'Question ${i+1}: duplicate choices not allowed.', backgroundColor: AppColors.error); return; }
        if(q.allowOther && opts.map((e)=>e.toLowerCase()).where((e)=>e=='other').length>1){ showAppSnackBar(context,'Question ${i+1}: Other duplicated.', backgroundColor: AppColors.error); return; }
      }
      if(q.conditionalParentId!=null){
        final parentIdx=_questions.indexWhere((qq)=>qq.id==q.conditionalParentId);
        if(parentIdx==-1 || parentIdx>=i){ showAppSnackBar(context,'Question ${i+1}: conditional parent must be an earlier question.', backgroundColor: AppColors.error); return; }
        if(q.conditionalTrigger.text.trim().isEmpty){ showAppSnackBar(context,'Question ${i+1}: conditional trigger value required.', backgroundColor: AppColors.error); return; }
      }
      if(q.charLimit.text.trim().isNotEmpty){
        final lim=int.tryParse(q.charLimit.text.trim());
        if(lim==null || lim<1 || lim>5000){ showAppSnackBar(context,'Question ${i+1}: character limit 1-5000.', backgroundColor: AppColors.error); return; }
      }
      questionsData.add(q.toJson(i));
    }
    setState(()=>_saving=true);
    final data={
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'targetBatchYear': _targetBatch==null||_targetBatch=='' ? null : int.tryParse(_targetBatch!),
      'openingDate': _openingDate?.toIso8601String(),
      'closingDate': _closingDate?.toIso8601String(),
      'status': _status,
      'allowUpdate': _allowUpdate,
      'visibility': _visibility,
      'questions': questionsData,
    };
    try{
      final service=ref.read(surveyServiceProvider);
      if(_isEdit) await service.updateSurvey(widget.existing!['id']?.toString()??'', data);
      else await service.createSurvey(data);
      if(mounted){ showAppSnackBar(context,'Survey saved successfully.', backgroundColor: AppColors.success); Navigator.pop(context,true); }
    }catch(e){ if(mounted) showAppSnackBar(context,'Save failed: ${AuthService.friendlyError(e)}', backgroundColor: AppColors.error); }
    finally{ if(mounted) setState(()=>_saving=false); }
  }

  Widget _buildQuestionCard(int index, _QuestionDraft q){
    final isDark=Theme.of(context).brightness==Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: q.isPublished? (isDark? AppColors.borderDark: AppColors.outlineCard) : AppColors.warning.withOpacity(0.5), width: q.isPublished?1.2:1.5)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle_rounded, size: 20, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(child: Text('Question ${index+1}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: isDark? Colors.white: AppColors.primaryNavy))),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Duplicate', icon: const Icon(Icons.copy_rounded, size: 16), onPressed: ()=>_duplicateQuestion(index)),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), onPressed: ()=>_removeQuestion(index)),
        ]),
        const SizedBox(height: 8),
        TextFormField(controller: q.text, maxLines: 2, decoration: const InputDecoration(labelText: 'Question text *', hintText: 'e.g. What is your current job role?'), validator: (v)=> (v==null||v.trim().isEmpty)?'Required':null),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: _questionTypeLabels.containsKey(q.type)? q.type : 'short_text', decoration: const InputDecoration(labelText: 'Question Type'), isExpanded: true, items: _questionTypeLabels.entries.map((e)=>DropdownMenuItem(value:e.key, child: Text(e.value, style: GoogleFonts.poppins(fontSize:13)))).toList(), onChanged: (v){ if(v==null) return; setState(()=>q.type=v); }),
        const SizedBox(height: 8),
        Row(children:[
          Expanded(child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('Required', style: GoogleFonts.poppins(fontSize:12)), value: q.isRequired, onChanged: (v)=>setState(()=>q.isRequired=v))),
          Expanded(child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('Published', style: GoogleFonts.poppins(fontSize:12)), value: q.isPublished, activeColor: AppColors.success, onChanged: (v)=>setState(()=>q.isPublished=v))),
        ]),
        // Written-answer extras
        if(q.type=='short_text'||q.type=='long_text') ...[
          const SizedBox(height: 8),
          TextFormField(controller: q.placeholder, decoration: const InputDecoration(labelText: 'Placeholder', hintText: 'e.g. Enter your answer')),
          const SizedBox(height: 8),
          TextFormField(controller: q.charLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Character limit (optional)', hintText: 'e.g. 500')),
        ],
        // Number/date placeholder
        if(q.type=='number') ...[
          const SizedBox(height: 8),
          TextFormField(controller: q.placeholder, decoration: const InputDecoration(labelText: 'Placeholder', hintText: 'e.g. 0')),
        ],
        if(q.type=='date') ...[
          const SizedBox(height: 8),
          TextFormField(controller: q.placeholder, decoration: const InputDecoration(labelText: 'Placeholder / Help text', hintText: 'e.g. YYYY-MM-DD')),
        ],
        // Options for dropdowns + yes_no
        if(q.type=='single_select'||q.type=='multi_select'||q.type=='yes_no') ...[
          const SizedBox(height: 10),
          if(q.type!='yes_no') ...[
            Text('Options', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize:12)),
            const SizedBox(height: 6),
            for(int i=0;i<q.options.length;i++) Row(children:[
              const Icon(Icons.radio_button_unchecked, size:16, color: Colors.grey),
              const SizedBox(width:8),
              Expanded(child: TextFormField(controller: q.options[i], decoration: const InputDecoration(isDense:true, hintText:'Option'))),
              IconButton(icon: const Icon(Icons.close_rounded, size:18), onPressed: ()=>setState((){ q.options.removeAt(i).dispose(); })),
              if(i>0) IconButton(icon: const Icon(Icons.arrow_upward_rounded, size:16), onPressed: ()=>setState((){ final c=q.options.removeAt(i); q.options.insert(i-1,c); })),
              if(i<q.options.length-1) IconButton(icon: const Icon(Icons.arrow_downward_rounded, size:16), onPressed: ()=>setState((){ final c=q.options.removeAt(i); q.options.insert(i+1,c); })),
            ]),
            const SizedBox(height: 6),
            Row(children:[
              Expanded(child: TextFormField(controller: q.newOption, decoration: const InputDecoration(hintText:'Type an option...', isDense:true), onFieldSubmitted: (_)=>_addOption(q))),
              IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue), onPressed: ()=>_addOption(q)),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(dense:true, contentPadding: EdgeInsets.zero, title: Text('Allow "Other" answer', style: GoogleFonts.poppins(fontSize:12)), subtitle: Text('Adds Other as final option with Please specify field', style: GoogleFonts.poppins(fontSize:10, color: Colors.grey)), value: q.allowOther, onChanged: (v)=>setState(()=>q.allowOther=v)),
          ] else ...[
            Text('Yes/No options are fixed: Yes, No', style: GoogleFonts.poppins(fontSize:12, color: Colors.grey)),
          ],
        ],
        // Conditional
        const SizedBox(height: 10),
        ExpansionTile(title: Text('Conditional display', style: GoogleFonts.poppins(fontSize:12, fontWeight: FontWeight.w600)), childrenPadding: const EdgeInsets.fromLTRB(12,0,12,12), children: [
          DropdownButtonFormField<String?>(initialValue: q.conditionalParentId, decoration: const InputDecoration(labelText:'Show only when answer to...', hintText:'Always show'), isExpanded:true, items: [
            const DropdownMenuItem(value:null, child: Text('Always show')),
            for(int i=0;i<index;i++) DropdownMenuItem(value:_questions[i].id, child: Text('Q${i+1}: ${_questions[i].text.text.isEmpty? 'Untitled': _questions[i].text.text}', overflow: TextOverflow.ellipsis)),
          ], onChanged: (v)=>setState(()=>q.conditionalParentId=v)),
          if(q.conditionalParentId!=null) ...[
            const SizedBox(height:8),
            TextFormField(controller: q.conditionalTrigger, decoration: InputDecoration(labelText:'Trigger answer value', hintText:'e.g. No, not related', helperText: 'Question appears only when this answer is selected')),
          ],
        ]),
      ])),
    );
  }

  @override
  Widget build(BuildContext context){
    final isDark=Theme.of(context).brightness==Brightness.dark;
    return Scaffold(
      backgroundColor: isDark? AppColors.surfaceDark: AppColors.surfaceLight,
      appBar: AppBar(backgroundColor: isDark? AppColors.surfaceDark: AppColors.surfaceLight, elevation:0, title: Text(_isEdit?'Edit Survey':'Create Survey', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: isDark?Colors.white:AppColors.primaryNavy))),
      body: Form(key:_formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Survey Information', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize:16, color: isDark?Colors.white:AppColors.primaryNavy)),
        const SizedBox(height:12),
        TextFormField(controller: _titleController, decoration: const InputDecoration(labelText:'Survey title *'), validator:(v)=>(v==null||v.trim().isEmpty)?'Required':null),
        const SizedBox(height:12),
        TextFormField(controller: _descriptionController, maxLines:3, decoration: const InputDecoration(labelText:'Survey description', hintText:'Purpose and instructions for alumni')),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(initialValue: _targetBatch, decoration: const InputDecoration(labelText:'Target batch year', hintText:'All batches if empty'), isExpanded:true, items: [const DropdownMenuItem(value:null, child: Text('All batches')), for(int y=DateTime.now().year+1; y>=2015; y--) DropdownMenuItem(value:y.toString(), child: Text('S.Y. $y–${y+1}'))], onChanged:(v)=>setState(()=>_targetBatch=v)),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: InkWell(onTap: ()=>_pickDate(true), child: InputDecorator(decoration: const InputDecoration(labelText:'Opening date'), child: Text(_openingDate==null?'Not set':DateFormat.yMMMd().format(_openingDate!), style: GoogleFonts.poppins(fontSize:13))))),
          const SizedBox(width:12),
          Expanded(child: InkWell(onTap: ()=>_pickDate(false), child: InputDecorator(decoration: const InputDecoration(labelText:'Closing date'), child: Text(_closingDate==null?'Not set':DateFormat.yMMMd().format(_closingDate!), style: GoogleFonts.poppins(fontSize:13))))),
        ]),
        if(_openingDate!=null||_closingDate!=null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: ()=>setState((){ _openingDate=null; _closingDate=null; }), child: Text('Clear dates', style: GoogleFonts.poppins(fontSize:11)))),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText:'Survey status'), items: const [DropdownMenuItem(value:'draft', child: Text('Draft')), DropdownMenuItem(value:'published', child: Text('Published')), DropdownMenuItem(value:'closed', child: Text('Closed'))], onChanged:(v)=>setState(()=>_status=v??'draft')),
        SwitchListTile(title: Text('Allow alumni to update answers', style: GoogleFonts.poppins(fontSize:12)), value: _allowUpdate, onChanged:(v)=>setState(()=>_allowUpdate=v)),
        DropdownButtonFormField<String>(initialValue: _visibility, decoration: const InputDecoration(labelText:'Visibility'), items: const [DropdownMenuItem(value:'public', child: Text('Public')), DropdownMenuItem(value:'private', child: Text('Private'))], onChanged:(v)=>setState(()=>_visibility=v??'public')),
        const Divider(height:32),
        Row(children:[Text('Questions', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize:16, color: isDark?Colors.white:AppColors.primaryNavy)), const Spacer(), Text('${_questions.length} questions', style: GoogleFonts.poppins(fontSize:12, color: isDark? const Color(0xFF94A3B8):AppColors.textSecondary))]),
        const SizedBox(height:8),
        Text('Alumni will see published questions in order. Use drag handle to reorder.', style: GoogleFonts.poppins(fontSize:11, color: isDark? const Color(0xFF94A3B8):AppColors.textSecondary)),
        const SizedBox(height:12),
        ReorderableListView.builder(
          shrinkWrap:true, physics: const NeverScrollableScrollPhysics(),
          itemCount: _questions.length,
          onReorder:(o,n){ setState((){ if(n>o) n-=1; final q=_questions.removeAt(o); _questions.insert(n,q); }); },
          itemBuilder:(c,i)=>Container(key: ValueKey(_questions[i].id), child: _buildQuestionCard(i, _questions[i])),
        ),
        const SizedBox(height:12),
        OutlinedButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add_rounded), label: Text('Add Question', style: GoogleFonts.poppins())),
        const SizedBox(height:20),
        ElevatedButton(onPressed: _saving?null:_save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:14)), child: _saving? const SizedBox(width:20,height:20, child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)): Text(_isEdit?'Update Survey':'Create Survey', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
        const SizedBox(height:12),
      ])),
    );
  }
}
