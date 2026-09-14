import 'package:flutter/material.dart';
import 'user_model.dart' show parseApiDate;

enum NotificationType {
  system,
  event,
  employment,
  survey,
  announcement,
  document;

  IconData get icon {
    switch (this) {
      case NotificationType.system:
        return Icons.settings;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.employment:
        return Icons.work;
      case NotificationType.survey:
        return Icons.assessment;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.document:
        return Icons.description;
    }
  }

  String get label {
    switch (this) {
      case NotificationType.system:
        return 'System';
      case NotificationType.event:
        return 'Events';
      case NotificationType.employment:
        return 'Employment';
      case NotificationType.survey:
        return 'Survey';
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.document:
        return 'Document';
    }
  }

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationType.system,
    );
  }
}

enum NotificationPriority {
  low,
  medium,
  high;

  Color get color {
    switch (this) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.medium:
        return Colors.orange;
      case NotificationPriority.high:
        return Colors.red;
    }
  }

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationPriority.medium,
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String description;
  final NotificationPriority priority;
  final bool isRead;
  final DateTime createdAt;
  final String? link;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.priority = NotificationPriority.medium,
    this.isRead = false,
    required this.createdAt,
    this.link,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? description,
    NotificationPriority? priority,
    bool? isRead,
    DateTime? createdAt,
    String? link,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      link: link ?? this.link,
    );
  }

  static DateTime _parseDate(dynamic val) {
    return parseApiDate(val) ?? DateTime.now();
  }

  factory AppNotification.fromJson(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      userId: map['userId']?.toString() ?? '',
      type: NotificationType.fromString(map['type']?.toString() ?? 'system'),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      priority:
          NotificationPriority.fromString(map['priority']?.toString() ?? 'medium'),
      isRead: map['isRead'] == true,
      createdAt: _parseDate(map['createdAt']),
      link: map['link']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'description': description,
      'priority': priority.name,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'link': link,
    };
  }

  /// Backwards-compatible alias (the REST API uses [toJson]).
  Map<String, dynamic> toMap() => toJson();
}
