import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../services/api_client.dart';

/// Generic CRUD for the staff-managed content collections served by
/// `GET|POST|PATCH|DELETE /api/content/:collection`:
/// announcements, events, jobs, reports.
class ContentRepository {
  ContentRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  static const announcements = 'announcements';
  static const events = 'events';
  static const jobs = 'jobs';
  static const reports = 'reports';

  Stream<List<Map<String, dynamic>>> watchCollection(
    String collection, {
    bool publicOnly = false,
  }) {
    return _api.poll(
      () => fetchCollection(collection, publicOnly: publicOnly),
      interval: pollInterval,
    );
  }

  Future<List<Map<String, dynamic>>> fetchCollection(
    String collection, {
    bool publicOnly = false,
  }) async {
    final raw = await _api.get('/api/content/$collection', query: {
      if (publicOnly) 'visibility': 'public',
    });
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createItem(
    String collection,
    Map<String, dynamic> body,
  ) async {
    final raw = await _api.post('/api/content/$collection', body: body);
    return Map<String, dynamic>.from(raw);
  }

  Future<void> updateItem(
    String collection,
    String id,
    Map<String, dynamic> changes,
  ) {
    return _api.patch('/api/content/$collection/$id', body: changes);
  }

  Future<void> deleteItem(String collection, String id) {
    return _api.delete('/api/content/$collection/$id');
  }

  /// System settings as editable rows ({id, name, value}).
  Stream<List<Map<String, dynamic>>> watchSettings() {
    return _api.poll(fetchSettings, interval: pollInterval);
  }

  Future<List<Map<String, dynamic>>> fetchSettings() async {
    final raw = await _api.get('/api/settings');
    final map = Map<String, dynamic>.from(raw);
    return [
      for (final entry in map.entries)
        {
          'id': entry.key,
          'name': entry.key,
          'value': entry.value is String
              ? entry.value
              : jsonEncode(entry.value),
        },
    ];
  }

  Future<void> saveSetting(String name, String value) {
    return _api.put('/api/settings', body: {name: value});
  }
}

final contentRepositoryProvider = Provider<ContentRepository>(
    (ref) => ContentRepository(api: ref.watch(apiClientProvider)));
