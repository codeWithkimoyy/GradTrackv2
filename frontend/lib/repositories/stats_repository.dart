import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

/// One month bucket in a 12-month trend series.
class TrendPoint {
  final DateTime month;
  final int count;

  const TrendPoint(this.month, this.count);
}

/// Employment outcome for a single graduation-year batch.
class YearEmployment {
  final int year;
  final int employedCount;
  final int total;

  const YearEmployment(this.year, this.employedCount, this.total);

  double get rate => total == 0 ? 0 : (employedCount / total) * 100;
}

/// Live aggregate counts for staff dashboards, derived from real Firestore
/// documents (users, surveys, survey responses, events, announcements).
class DashboardStats {
  final int totalUsers;
  final int admins;
  final int coordinators;
  final int alumni;
  final int guests;
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
    this.coordinators = 0,
    this.alumni = 0,
    this.guests = 0,
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

/// How many published surveys an alumni has already answered.
class SurveyProgress {
  final int completed;
  final int total;

  const SurveyProgress({this.completed = 0, this.total = 0});

  bool get hasSurveys => total > 0;
  bool get fullyAnswered => hasSurveys && completed >= total;
  double get rate => total == 0 ? 0 : completed / total;
}

/// Merges multiple live query streams: whenever any source emits, the latest
/// snapshot of every source is combined and emitted downstream.
class StreamCombiner {
  final List<Stream<QuerySnapshot<Map<String, dynamic>>>> _sources;
  final List<QuerySnapshot<Map<String, dynamic>>?> _latest;
  StreamController<dynamic>? _controller;
  final List<StreamSubscription<dynamic>> _subs = [];

  StreamCombiner(this._sources)
      : _latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
            _sources.length, null);

  Stream<T> bind<T>(T Function(List<QuerySnapshot<Map<String, dynamic>>>) fn) {
    if (_controller != null) {
      throw StateError('Combiner already bound');
    }
    final controller = StreamController<T>();
    _controller = controller;
    controller.onCancel = () {
      _dispose();
    };
    for (var i = 0; i < _sources.length; i++) {
      _subs.add(_sources[i].listen((snap) {
        _latest[i] = snap;
        if (_latest.every((s) => s != null) && !controller.isClosed) {
          controller.add(fn(
              _latest.cast<QuerySnapshot<Map<String, dynamic>>>().toList()));
        }
      }));
    }
    return controller.stream;
  }

  void _dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _controller?.close();
  }
}

class StatsRepository {
  final FirebaseFirestore _firestore;

  StatsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _firestore.collection(name);

  /// Live combined stats for admin/coordinator dashboards and analytics.
  /// Reads the user list plus survey, response, event and announcement
  /// collections. Admins may list every user; coordinators are scoped to
  /// alumni and guest records by the security rules, so the equivalent
  /// query filter is applied here too.
  Stream<DashboardStats> watchStaffStats({bool adminScope = true}) {
    final userQuery = adminScope
        ? _users.snapshots()
        : _users
            .where('role', whereIn: const ['alumni', 'guest'])
            .snapshots();
    final users = userQuery;
    final surveys = _col(FirestoreCollections.surveys).snapshots();
    final responses = _col(FirestoreCollections.surveyResponses).snapshots();
    final events = _col(FirestoreCollections.events).snapshots();
    final announcements = _col(FirestoreCollections.announcements).snapshots();

    final combiner = StreamCombiner(
        [users, surveys, responses, events, announcements]);
    return combiner.bind((snaps) {
      final userDocs = snaps[0].docs;
      final surveysSnap = snaps[1];
      final responsesSnap = snaps[2];

      int countRole(String role) =>
          userDocs.where((d) => d.data()['role'] == role).length;

      final alumniDocs =
          userDocs.where((d) => d.data()['role'] == 'alumni').toList();
      final verified =
          alumniDocs.where((d) => d.data()['isVerified'] == true).length;

      int countStatus(String status) => alumniDocs
          .where((d) =>
              (d.data()['employmentStatus'] as String? ?? 'unemployed') ==
              status)
          .length;

      return DashboardStats(
        totalUsers: userDocs.length,
        admins: countRole('admin'),
        coordinators: countRole('coordinator'),
        alumni: alumniDocs.length,
        guests: countRole('guest'),
        verifiedAlumni: verified,
        pendingAlumni: alumniDocs.length - verified,
        employed: countStatus('employed'),
        selfEmployed: countStatus('selfEmployed'),
        freelance: countStatus('freelance'),
        unemployed: countStatus('unemployed'),
        studying: countStatus('studying'),
        surveyCount: surveysSnap.docs.length,
        responseCount: responsesSnap.docs.length,
        eventCount: snaps[3].docs.length,
        announcementCount: snaps[4].docs.length,
        signupTrend: _monthlyTrend(
          userDocs.map((d) => (d.data()['createdAt'] as Timestamp?)?.toDate()),
        ),
        responseTrend: _monthlyTrend(
          responsesSnap.docs
              .map((d) => (d.data()['completedAt'] as Timestamp?)?.toDate()),
        ),
        employmentByYear: _employmentByYear(alumniDocs),
      );
    });
  }

  /// Buckets [dates] into the last 12 calendar months (oldest first).
  /// Null/missing timestamps are skipped; future dates are ignored.
  static List<TrendPoint> _monthlyTrend(
      Iterable<DateTime?> dates) {
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

  /// Groups alumni docs by graduation year and counts working alumni
  /// (employed / self-employed / freelance) per batch. Years without a
  /// value are skipped; sorted ascending.
  static List<YearEmployment> _employmentByYear(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> alumniDocs) {
    final byYear = <int, (int, int)>{};
    for (final doc in alumniDocs) {
      final data = doc.data();
      final year = data['graduationYear'];
      if (year is! int) continue;
      final status = data['employmentStatus'] as String? ?? 'unemployed';
      final working =
          status == 'employed' || status == 'selfEmployed' || status == 'freelance';
      final tally = byYear[year] ?? (0, 0);
      byYear[year] = (
        tally.$1 + (working ? 1 : 0),
        tally.$2 + 1,
      );
    }
    final entries = byYear.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      for (final e in entries) YearEmployment(e.key, e.value.$1, e.value.$2),
    ];
  }

  /// Live list of users whose account is awaiting admin approval
  /// (approved == false), newest registration first. Admins only —
  /// the security rules scope this query to the admin role.
  ///
  /// Query uses only a single equality filter with no Firestore orderBy
  /// clause so it requires ZERO composite indexes. Sorting by [createdAt]
  /// and [limit] are applied in-memory on the client stream.
  Stream<List<Map<String, dynamic>>> watchPendingApprovals({int limit = 20}) {
    return _users
        .where('approved', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      list.sort((a, b) {
        final aDate = (a['createdAt'] as Timestamp?)?.toDate();
        final bDate = (b['createdAt'] as Timestamp?)?.toDate();
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      if (limit > 0 && list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    });
  }

  /// High-performance server-side aggregation using Firestore count() queries.
  Future<DashboardStats> fetchAggregatedStaffStats({bool adminScope = true}) async {
    try {
      final totalQuery = adminScope
          ? _users
          : _users.where('role', whereIn: const ['alumni', 'guest']);

      final results = await Future.wait([
        totalQuery.count().get(),
        _users.where('role', isEqualTo: 'admin').count().get(),
        _users.where('role', isEqualTo: 'coordinator').count().get(),
        _users.where('role', isEqualTo: 'alumni').count().get(),
        _users.where('role', isEqualTo: 'guest').count().get(),
        _users
            .where('role', isEqualTo: 'alumni')
            .where('isVerified', isEqualTo: true)
            .count()
            .get(),
        _users.where('employmentStatus', isEqualTo: 'employed').count().get(),
        _users.where('employmentStatus', isEqualTo: 'selfEmployed').count().get(),
        _users.where('employmentStatus', isEqualTo: 'freelance').count().get(),
        _users.where('employmentStatus', isEqualTo: 'unemployed').count().get(),
        _users.where('employmentStatus', isEqualTo: 'studying').count().get(),
        _col(FirestoreCollections.surveys).count().get(),
        _col(FirestoreCollections.surveyResponses).count().get(),
        _col(FirestoreCollections.events).count().get(),
        _col(FirestoreCollections.announcements).count().get(),
      ]);

      final total = results[0].count ?? 0;
      final alumni = results[3].count ?? 0;
      final verified = results[5].count ?? 0;

      return DashboardStats(
        totalUsers: total,
        admins: results[1].count ?? 0,
        coordinators: results[2].count ?? 0,
        alumni: alumni,
        guests: results[4].count ?? 0,
        verifiedAlumni: verified,
        pendingAlumni: (alumni - verified).clamp(0, alumni),
        employed: results[6].count ?? 0,
        selfEmployed: results[7].count ?? 0,
        freelance: results[8].count ?? 0,
        unemployed: results[9].count ?? 0,
        studying: results[10].count ?? 0,
        surveyCount: results[11].count ?? 0,
        responseCount: results[12].count ?? 0,
        eventCount: results[13].count ?? 0,
        announcementCount: results[14].count ?? 0,
      );
    } catch (_) {
      return DashboardStats.empty;
    }
  }

  /// Live tracer-survey progress for one alumni user.
  Stream<SurveyProgress> watchSurveyProgress(String userId) {
    final surveys = _col(FirestoreCollections.surveys).snapshots();
    final responses = _col(FirestoreCollections.surveyResponses)
        .where('userId', isEqualTo: userId)
        .snapshots();

    final combiner = StreamCombiner([surveys, responses]);
    return combiner.bind((snaps) {
      return SurveyProgress(
        completed: snaps[1].docs.length,
        total: snaps[0].docs.length,
      );
    });
  }

  /// Live announcements for alumni dashboards (all) or public-facing screens.
  Stream<List<Map<String, dynamic>>> watchAnnouncements({
    bool publicOnly = false,
  }) {
    Query<Map<String, dynamic>> query =
        _col(FirestoreCollections.announcements);
    if (publicOnly) {
      query = query.where('visibility', isEqualTo: 'public');
    }
    return query.orderBy('createdAt', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => d.data()).toList());
  }
}