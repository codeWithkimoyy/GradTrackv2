import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

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
      );
    });
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