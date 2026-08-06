import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkSetup { remote, hybrid, onSite }

extension WorkSetupX on WorkSetup {
  String get label => switch (this) {
        WorkSetup.remote => 'Remote',
        WorkSetup.hybrid => 'Hybrid',
        WorkSetup.onSite => 'On-site',
      };

  static WorkSetup fromString(String value) => WorkSetup.values.firstWhere(
        (w) => w.name == value,
        orElse: () => WorkSetup.onSite,
      );
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
    required this.country,
    this.province,
    required this.city,
    required this.workSetup,
    this.jobDescription,
    this.isCurrent = true,
    required this.createdAt,
  });

  factory EmploymentRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return EmploymentRecord(
      id: doc.id,
      userId: map['userId'] ?? '',
      company: map['company'] ?? '',
      position: map['position'] ?? '',
      industry: map['industry'] ?? '',
      employmentType: map['employmentType'] ?? '',
      salaryRange: map['salaryRange'],
      dateHired: (map['dateHired'] as Timestamp?)?.toDate() ?? DateTime.now(),
      country: map['country'] ?? '',
      province: map['province'],
      city: map['city'] ?? '',
      workSetup: WorkSetupX.fromString(map['workSetup'] ?? 'onSite'),
      jobDescription: map['jobDescription'],
      isCurrent: map['isCurrent'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'company': company,
        'position': position,
        'industry': industry,
        'employmentType': employmentType,
        'salaryRange': salaryRange,
        'dateHired': Timestamp.fromDate(dateHired),
        'country': country,
        'province': province,
        'city': city,
        'workSetup': workSetup.name,
        'jobDescription': jobDescription,
        'isCurrent': isCurrent,
        'createdAt': Timestamp.fromDate(createdAt),
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

  factory CareerMilestone.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return CareerMilestone(
      id: doc.id,
      userId: map['userId'] ?? '',
      type: MilestoneType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MilestoneType.firstJob,
      ),
      title: map['title'] ?? '',
      description: map['description'],
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type.name,
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
      };
}
