import '../models/employment_model.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

/// Encapsulates all backend reads/writes for employment records and
/// career milestones. Screens/providers should go through this rather
/// than touching the API directly.
class EmploymentRepository {
  EmploymentRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  List<EmploymentRecord> _parseRecords(dynamic raw) {
    final list = (raw as List).cast<Map<String, dynamic>>();
    final records = list
        .map((m) => EmploymentRecord.fromJson(m, m['id']?.toString() ?? ''))
        .toList()
      ..sort((x, y) => y.dateHired.compareTo(x.dateHired));
    return records;
  }

  /// Employment history for a user (admins may pass another user's id),
  /// most recent first.
  Stream<List<EmploymentRecord>> watchRecords(String userId) {
    return _api.poll(() => fetchRecords(userId), interval: pollInterval);
  }

  Future<List<EmploymentRecord>> fetchRecords(String userId) async {
    if (_api.currentUid == null || _api.currentUid == userId) {
      return _parseRecords(await _api.get('/api/employment/mine'));
    }
    return _parseRecords(await _api.get('/api/employment/user/$userId'));
  }

  /// Every employment record across every alumnus, newest first. Powers the
  /// admin's aggregate Employment History view.
  Stream<List<EmploymentRecord>> watchAllRecords() {
    return _api.poll(fetchAllRecords, interval: pollInterval);
  }

  Future<List<EmploymentRecord>> fetchAllRecords() async {
    return _parseRecords(await _api.get('/api/employment/all'));
  }

  Stream<List<CareerMilestone>> watchMilestones(String userId) {
    return _api.poll(() => fetchMilestones(userId), interval: pollInterval);
  }

  Future<List<CareerMilestone>> fetchMilestones(String userId) async {
    final raw = await _api
        .get('/api/employment/milestones', query: {'userId': userId});
    final list = (raw as List).cast<Map<String, dynamic>>();
    final milestones = list
        .map((m) => CareerMilestone.fromJson(m, m['id']?.toString() ?? ''))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return milestones;
  }

  /// Creates a record; the backend demotes previous current jobs, syncs the
  /// profile employment status and adds the first-job milestone as needed.
  Future<EmploymentRecord> addRecord(EmploymentRecord record) async {
    final raw = await _api.post('/api/employment', body: record.toMap());
    final map = Map<String, dynamic>.from(raw);
    return EmploymentRecord.fromJson(map, map['id']?.toString() ?? '');
  }

  Future<void> updateRecord(String recordId, Map<String, dynamic> changes) {
    return _api.patch('/api/employment/$recordId', body: changes);
  }

  Future<void> deleteRecord(String recordId) {
    return _api.delete('/api/employment/$recordId');
  }

  Future<CareerMilestone> addMilestone(CareerMilestone milestone) async {
    final raw =
        await _api.post('/api/employment/milestones', body: milestone.toMap());
    final map = Map<String, dynamic>.from(raw);
    return CareerMilestone.fromJson(map, map['id']?.toString() ?? '');
  }

  Future<void> deleteMilestone(String id) {
    return _api.delete('/api/employment/milestones/$id');
  }

  Future<void> setEmploymentStatus(
      String userId, EmploymentStatus status) async {
    if (_api.currentUid == null || _api.currentUid == userId) {
      await _api.patch('/api/employment/status/self',
          body: {'employmentStatus': status.name});
    } else {
      await _api.patch('/api/alumni/users/$userId',
          body: {'employmentStatus': status.name});
    }
  }
}
