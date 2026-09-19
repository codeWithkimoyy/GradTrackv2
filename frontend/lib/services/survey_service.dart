import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import 'api_client.dart';

/// Tracer surveys + responses served by `/api/surveys`.
class SurveyService {
  SurveyService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  Stream<List<Map<String, dynamic>>> watchSurveys({bool publicOnly = false}) {
    return _api.poll(() => fetchSurveys(publicOnly: publicOnly),
        interval: pollInterval);
  }

  Future<List<Map<String, dynamic>>> fetchSurveys(
      {bool publicOnly = false}) async {
    final raw = await _api.get('/api/surveys', query: {
      if (publicOnly) 'visibility': 'public',
    });
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchSurvey(String id) async {
    final raw = await _api.get('/api/surveys/$id');
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> createSurvey(Map<String, dynamic> body) async {
    final raw = await _api.post('/api/surveys', body: body);
    return Map<String, dynamic>.from(raw);
  }

  Future<void> updateSurvey(String id, Map<String, dynamic> changes) {
    return _api.patch('/api/surveys/$id', body: changes);
  }

  Future<void> deleteSurvey(String id) {
    return _api.delete('/api/surveys/$id');
  }

  Future<void> reorderQuestions(String surveyId, List<String> orderedIds) {
    return _api.put('/api/surveys/$surveyId/questions/reorder', body: {'order': orderedIds});
  }

  Future<List<Map<String, dynamic>>> fetchResponsesFiltered(String surveyId, {String? batch, String? employment, String? q, String? dateFrom, String? dateTo, bool? archived}) async {
    final query = <String,String>{};
    if (batch != null) query['batch'] = batch;
    if (employment != null) query['employment'] = employment;
    if (q != null) query['q'] = q;
    if (dateFrom != null) query['dateFrom'] = dateFrom;
    if (dateTo != null) query['dateTo'] = dateTo;
    if (archived != null) query['archived'] = archived ? '1' : '0';
    final raw = await _api.get('/api/surveys/$surveyId/responses', query: query);
    return (raw as List).cast<Map<String,dynamic>>();
  }

  Future<void> archiveResponse(String responseId, bool archived) {
    return _api.patch('/api/surveys/responses/$responseId/archive', body: {'archived': archived});
  }

  Future<Map<String,dynamic>> fetchSummary(String surveyId) async {
    final raw = await _api.get('/api/surveys/$surveyId/summary');
    return Map<String,dynamic>.from(raw as Map);
  }

  Future<String> exportCsv(String surveyId) async {
    final raw = await _api.get('/api/surveys/$surveyId/export', query: {'format':'csv'});
    // raw is csv string? api returns text/csv, but ApiClient may parse as string
    return raw.toString();
  }

  Stream<List<Map<String, dynamic>>> watchResponses(String surveyId) {
    return _api.poll(() => fetchResponses(surveyId),
        interval: pollInterval);
  }

  Future<List<Map<String, dynamic>>> fetchResponses(String surveyId) async {
    final raw = await _api.get('/api/surveys/$surveyId/responses');
    final list = (raw as List).cast<Map<String, dynamic>>();
    list.sort((a, b) {
      final at = a['completedAt']?.toString() ?? '';
      final bt = b['completedAt']?.toString() ?? '';
      return bt.compareTo(at);
    });
    return list;
  }

  Future<List<Map<String, dynamic>>> fetchMyResponses() async {
    final raw = await _api.get('/api/surveys/responses/mine');
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> submitResponse(
      String surveyId, Map<String, dynamic> answers,
      {Map<String, dynamic>? customOthers, String? status}) async {
    final body = <String, dynamic>{'surveyId': surveyId, 'answers': answers};
    if (customOthers != null && customOthers.isNotEmpty) body['customOthers'] = customOthers;
    if (status != null) body['status'] = status;
    final raw = await _api.post('/api/surveys/responses', body: body);
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> fetchSurveyReport(String surveyId) async {
    final raw = await _api.get('/api/surveys/$surveyId/reports');
    return Map<String, dynamic>.from(raw);
  }

  Future<List<int>> fetchBatches() async {
    final raw = await _api.get('/api/alumni/batches');
    return (raw as List).map((e) => (e as num).toInt()).toList();
  }
}

final surveyServiceProvider = Provider<SurveyService>(
    (ref) => SurveyService(api: ref.watch(apiClientProvider)));

/// All published surveys (alumni view).
final surveysProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(surveyServiceProvider).watchSurveys();
});

/// The signed-in alumni's own survey responses.
final mySurveyResponsesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(surveyServiceProvider);
  return service._api.poll(service.fetchMyResponses,
      interval: SurveyService.pollInterval);
});

/// Aggregated report for a specific survey (admin view).
final surveyReportProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, surveyId) {
  return ref.watch(surveyServiceProvider).fetchSurveyReport(surveyId);
});

/// Distinct graduation years from the alumni directory (for batch picker).
final batchesProvider =
    FutureProvider.autoDispose<List<int>>((ref) {
  return ref.watch(surveyServiceProvider).fetchBatches();
});
