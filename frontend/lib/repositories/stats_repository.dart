import '../models/user_model.dart';
import '../services/api_client.dart';

/// One month bucket in a 12-month trend series.
class TrendPoint {
  final DateTime month;
  final int count;

  const TrendPoint(this.month, this.count);

  factory TrendPoint.fromJson(Map<String, dynamic> map) {
    return TrendPoint(
      parseApiDate(map['month']) ?? DateTime.now(),
      (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Employment outcome for a single graduation-year batch.
class YearEmployment {
  final int year;
  final int employedCount;
  final int total;

  const YearEmployment(this.year, this.employedCount, this.total);

  factory YearEmployment.fromJson(Map<String, dynamic> map) {
    return YearEmployment(
      (map['year'] as num?)?.toInt() ?? 0,
      (map['employedCount'] as num?)?.toInt() ?? 0,
      (map['total'] as num?)?.toInt() ?? 0,
    );
  }

  double get rate => total == 0 ? 0 : (employedCount / total) * 100;
}

/// Aggregate counts for staff dashboards, computed server-side from MySQL.
class DashboardStats {
  final int totalUsers;
  final int admins;
  final int alumni;
  final int verifiedAlumni;
  final int pendingAlumni;
  final int employed;
  final int selfEmployed;
  final int freelance;
  final int unemployed;
  final int studying;
  final int surveyCount;
  final int responseCount;
  final int eventCount;
  final int announcementCount;

  /// 12-month new-user signup series (oldest month first).
  final List<TrendPoint> signupTrend;

  /// Survey responses per month for the last 12 months (oldest first).
  final List<TrendPoint> responseTrend;

  /// Alumni employed (employed/self-employed/freelance) per graduation year,
  /// sorted by year ascending. Drives the outcome-by-batch chart.
  final List<YearEmployment> employmentByYear;

  const DashboardStats({
    this.totalUsers = 0,
    this.admins = 0,
    this.alumni = 0,
    this.verifiedAlumni = 0,
    this.pendingAlumni = 0,
    this.employed = 0,
    this.selfEmployed = 0,
    this.freelance = 0,
    this.unemployed = 0,
    this.studying = 0,
    this.surveyCount = 0,
    this.responseCount = 0,
    this.eventCount = 0,
    this.announcementCount = 0,
    this.signupTrend = const [],
    this.responseTrend = const [],
    this.employmentByYear = const [],
  });

  static const empty = DashboardStats();

  factory DashboardStats.fromJson(Map<String, dynamic> map) {
    int getInt(String key) => (map[key] as num?)?.toInt() ?? 0;
    List<TrendPoint> trends(String key) {
      final raw = map[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(TrendPoint.fromJson)
          .toList();
    }

    return DashboardStats(
      totalUsers: getInt('totalUsers'),
      admins: getInt('admins'),
      alumni: getInt('alumni'),
      verifiedAlumni: getInt('verifiedAlumni'),
      pendingAlumni: getInt('pendingAlumni'),
      employed: getInt('employed'),
      selfEmployed: getInt('selfEmployed'),
      freelance: getInt('freelance'),
      unemployed: getInt('unemployed'),
      studying: getInt('studying'),
      surveyCount: getInt('surveyCount'),
      responseCount: getInt('responseCount'),
      eventCount: getInt('eventCount'),
      announcementCount: getInt('announcementCount'),
      signupTrend: trends('signupTrend'),
      responseTrend: trends('responseTrend'),
      employmentByYear: (map['employmentByYear'] is List)
          ? (map['employmentByYear'] as List)
              .whereType<Map<String, dynamic>>()
              .map(YearEmployment.fromJson)
              .toList()
          : const [],
    );
  }

  double get employmentRate {
    final working = employed + selfEmployed + freelance;
    final total = working + unemployed + studying;
    if (total == 0) return 0;
    return (working / total) * 100;
  }

  double get verificationRate {
    if (alumni == 0) return 0;
    return (verifiedAlumni / alumni) * 100;
  }

  double get surveyCompletionRate {
    if (surveyCount == 0) return 0;
    return (responseCount / surveyCount) * 100;
  }
}

/// One graduation batch and its alumni headcount.
class AlumniBatch {
  final String academicYear;
  final int count;

  const AlumniBatch({required this.academicYear, required this.count});

  factory AlumniBatch.fromJson(Map<String, dynamic> map) {
    return AlumniBatch(
      academicYear: map['academicYear']?.toString() ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// How many published surveys an alumni has already answered.
class SurveyProgress {
  final int completed;
  final int total;

  const SurveyProgress({this.completed = 0, this.total = 0});

  factory SurveyProgress.fromJson(Map<String, dynamic> map) {
    return SurveyProgress(
      completed: (map['completed'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasSurveys => total > 0;
  bool get fullyAnswered => hasSurveys && completed >= total;
  double get rate => total == 0 ? 0 : completed / total;
}

class StatsRepository {
  StatsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  /// Staff-facing aggregate stats, refreshed on a short poll.
  /// Admins see every role; non-admins are scoped to alumni records.
  Stream<DashboardStats> watchStaffStats({bool adminScope = true}) {
    return _api.poll(() => fetchAggregatedStaffStats(adminScope: adminScope),
        interval: pollInterval);
  }

  /// Alumni list grouped by graduation batch (newest batch first,
  /// legacy records that have neither academic year nor graduation year last).
  Stream<List<AlumniBatch>> watchAlumniBatches() {
    return _api.poll(fetchAlumniBatches, interval: pollInterval);
  }

  Future<List<AlumniBatch>> fetchAlumniBatches() async {
    final raw = await _api.get('/api/stats/batches');
    final batches = (raw as List)
        .whereType<Map<String, dynamic>>()
        .map(AlumniBatch.fromJson)
        .toList()
      ..sort((a, b) {
        final (aYear, _) = graduationBatchInfo(a.academicYear);
        final (bYear, _) = graduationBatchInfo(b.academicYear);
        if (aYear != null && bYear != null) return bYear.compareTo(aYear);
        if (aYear == null) return 1;
        if (bYear == null) return -1;
        return 0;
      });
    return batches;
  }

  /// Buckets [dates] into the last 12 calendar months (oldest first).
  /// Null/missing timestamps are skipped; future dates are ignored.
  static List<TrendPoint> monthlyTrend(Iterable<DateTime?> dates) {
    final now = DateTime.now();
    final months = List<int>.filled(12, 0);
    final startMonth = DateTime(now.year, now.month - 11);
    for (final date in dates) {
      if (date == null) continue;
      final monthIndex =
          (date.year * 12 + date.month) - (startMonth.year * 12 + startMonth.month);
      if (monthIndex < 0 || monthIndex > 11) continue;
      months[monthIndex]++;
    }
    return [
      for (var i = 0; i < 12; i++)
        TrendPoint(DateTime(startMonth.year, startMonth.month + i),
            months[i]),
    ];
  }

  /// List of users whose account is awaiting admin approval
  /// (approved == false), newest registration first.
  Stream<List<UserModel>> watchPendingApprovals({int limit = 20}) {
    return _api.poll(() => fetchPendingApprovals(limit: limit),
        interval: pollInterval);
  }

  Future<List<UserModel>> fetchPendingApprovals({int limit = 20}) async {
    final raw = await _api
        .get('/api/stats/pending-approvals', query: {'limit': '$limit'});
    final list = (raw as List).cast<Map<String, dynamic>>();
    list.sort((a, b) {
      final aDate = parseApiDate(a['createdAt']);
      final bDate = parseApiDate(b['createdAt']);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    final items =
        list.map((m) => UserModel.fromJson(m, m['uid']?.toString() ?? ''));
    if (limit > 0 && list.length > limit) {
      return items.take(limit).toList();
    }
    return items.toList();
  }

  /// Server-side aggregation for staff dashboards and analytics.
  Future<DashboardStats> fetchAggregatedStaffStats(
      {bool adminScope = true}) async {
    try {
      final raw = await _api.get('/api/stats/staff',
          query: {'adminScope': adminScope ? 'true' : 'false'});
      return DashboardStats.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return DashboardStats.empty;
    }
  }

  /// Tracer-survey progress for one alumni user.
  Stream<SurveyProgress> watchSurveyProgress(String userId) {
    return _api.poll(() => fetchSurveyProgress(userId),
        interval: pollInterval);
  }

  Future<SurveyProgress> fetchSurveyProgress(String userId) async {
    final raw = await _api
        .get('/api/stats/survey-progress', query: {'userId': userId});
    return SurveyProgress.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Announcements for alumni dashboards (all) or public-facing screens.
  Stream<List<Map<String, dynamic>>> watchAnnouncements({
    bool publicOnly = false,
  }) {
    return _api.poll(() => fetchAnnouncements(publicOnly: publicOnly),
        interval: pollInterval);
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements({
    bool publicOnly = false,
  }) async {
    final raw = await _api.get('/api/stats/announcements',
        query: {'publicOnly': publicOnly ? 'true' : 'false'});
    return (raw as List).cast<Map<String, dynamic>>();
  }
}
