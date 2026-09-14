/// Parses API date values (ISO-8601 strings, epoch millis, or DateTime).
DateTime _parseDate(dynamic val, [DateTime? fallback]) {
  if (val is DateTime) return val;
  if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  return fallback ?? DateTime.now();
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum WorkSetup { remote, hybrid, onSite }

extension WorkSetupX on WorkSetup {
  String get label => switch (this) {
        WorkSetup.remote => 'Remote',
        WorkSetup.hybrid => 'Hybrid',
        WorkSetup.onSite => 'On-site',
      };

  static WorkSetup fromString(String value) => switch (value.toLowerCase()) {
        'remote' => WorkSetup.remote,
        'hybrid' => WorkSetup.hybrid,
        'on-site' || 'onsite' || 'on site' => WorkSetup.onSite,
        _ => WorkSetup.onSite,
      };
}

class EmploymentRecord {
  final String id;
  final String userId;
  final String company;
  final String position;
  final String industry;
  final String employmentType; // Full-time, Part-time, Contract, etc.
  final String? salaryRange;
  final DateTime dateHired;
  final DateTime? endDate;
  final String country;
  final String? province;
  final String city;
  final WorkSetup workSetup;
  final String? jobDescription;
  final bool isCurrent;
  final DateTime createdAt;

  const EmploymentRecord({
    required this.id,
    required this.userId,
    required this.company,
    required this.position,
    required this.industry,
    required this.employmentType,
    this.salaryRange,
    required this.dateHired,
    this.endDate,
    required this.country,
    this.province,
    required this.city,
    required this.workSetup,
    this.jobDescription,
    this.isCurrent = true,
    required this.createdAt,
  });

  factory EmploymentRecord.fromJson(Map<String, dynamic> map, String id) {
    return EmploymentRecord(
      id: id,
      userId: map['userId']?.toString() ?? '',
      company: map['company']?.toString() ?? '',
      position: map['position']?.toString() ?? '',
      industry: map['industry']?.toString() ?? '',
      employmentType: map['employmentType']?.toString() ?? '',
      salaryRange: map['salaryRange']?.toString(),
      dateHired: _parseDate(map['dateHired']),
      endDate: map['endDate'] != null ? _parseDate(map['endDate']) : null,
      country: map['country']?.toString() ?? '',
      province: map['province']?.toString(),
      city: map['city']?.toString() ?? '',
      workSetup: WorkSetupX.fromString(map['workSetup']?.toString() ?? 'onSite'),
      jobDescription: map['jobDescription']?.toString(),
      isCurrent: map['isCurrent'] == true || map['isCurrent'] == 1,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  /// Maps a document from the unified `jobs` collection (the shared store
  /// where alumni record employment and staff post opportunities) onto the
  /// same [EmploymentRecord] shape used everywhere else, so alumni history,
  /// admin aggregates and per-user views all reflect the same data.
  factory EmploymentRecord.fromJobJson(Map<String, dynamic> map, String id) {
    final endDate = map['endDate'] != null ? _parseDate(map['endDate']) : null;
    return EmploymentRecord(
      id: id,
      userId: map['createdBy']?.toString() ?? '',
      company: map['company']?.toString() ?? '',
      position: map['jobTitle']?.toString() ??
          map['title']?.toString() ??
          '',
      industry: map['industry']?.toString() ?? '',
      employmentType: map['employmentType']?.toString() ?? '',
      salaryRange: map['salary']?.toString(),
      dateHired: _parseDate(map['startDate']),
      endDate: endDate,
      country: '',
      province: null,
      city: map['location']?.toString() ?? '',
      workSetup: WorkSetupX.fromString(map['workSetup']?.toString() ?? ''),
      jobDescription: map['description']?.toString(),
      isCurrent: map['isCurrent'] == true || map['isCurrent'] == 1,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'company': company,
        'position': position,
        'industry': industry,
        'employmentType': employmentType,
        'salaryRange': salaryRange,
        'dateHired': _dateOnly(dateHired),
        'endDate': endDate != null ? _dateOnly(endDate!) : null,
        'country': country,
        'province': province,
        'city': city,
        'workSetup': workSetup.name,
        'jobDescription': jobDescription,
        'isCurrent': isCurrent,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A single milestone in a graduate's career timeline.
enum MilestoneType { firstJob, promotion, transfer, certification, award }

class CareerMilestone {
  final String id;
  final String userId;
  final MilestoneType type;
  final String title;
  final String? description;
  final DateTime date;

  const CareerMilestone({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.description,
    required this.date,
  });

  factory CareerMilestone.fromJson(Map<String, dynamic> map, String id) {
    return CareerMilestone(
      id: id,
      userId: map['userId']?.toString() ?? '',
      type: MilestoneType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MilestoneType.firstJob,
      ),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      date: _parseDate(map['date']),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type.name,
        'title': title,
        'description': description,
        'date': _dateOnly(date),
      };
}
