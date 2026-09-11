import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories of alumni-to-admin messages. Hiring opportunities are the
/// primary use case, but alumni may also request announcements or ask a
/// general question.
enum MessageSubject { hiring, announcement, inquiry }

extension MessageSubjectX on MessageSubject {
  String get label => switch (this) {
        MessageSubject.hiring => 'Hiring Opportunity',
        MessageSubject.announcement => 'Announcement Request',
        MessageSubject.inquiry => 'General Inquiry',
      };

  static MessageSubject fromString(String value) =>
      MessageSubject.values.firstWhere(
        (s) => s.name == value,
        orElse: () => MessageSubject.inquiry,
      );
}

/// A message an alumni sends to the alumni office (admins), typically to
/// share a hiring opportunity so the staff can post an announcement.
class AlumniMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAlumniId;
  final String? senderEmail;
  final MessageSubject subject;
  final String? company;
  final String? position;
  final String details;
  final DateTime createdAt;

  const AlumniMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAlumniId,
    this.senderEmail,
    required this.subject,
    this.company,
    this.position,
    required this.details,
    required this.createdAt,
  });

  /// The initials shown in the admin inbox avatar.
  String get initials => senderName.isEmpty
      ? '?'
      : senderName
          .trim()
          .split(RegExp(r'\s+'))
          .take(2)
          .map((w) => w[0].toUpperCase())
          .join();

  factory AlumniMessage.fromMap(Map<String, dynamic> map, String id) {
    return AlumniMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAlumniId: map['senderAlumniId'],
      senderEmail: map['senderEmail'],
      subject: MessageSubjectX.fromString(map['subject'] ?? 'inquiry'),
      company: map['company'],
      position: map['position'],
      details: map['message'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'userId': senderId,
        'recipientRole': 'admin',
        'senderName': senderName,
        'senderAlumniId': senderAlumniId,
        'senderEmail': senderEmail,
        'subject': subject.name,
        'company': company,
        'position': position,
        'message': details,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}