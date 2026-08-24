import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase of a traced execution. `call` marks an explicit logic point recorded
/// from UI/providers, the rest map to Riverpod `AsyncValue` transitions.
enum TracePhase { start, loading, data, error, call }

class TraceEntry {
  const TraceEntry({
    required this.time,
    required this.source,
    required this.phase,
    this.detail = '',
  });

  final DateTime time;
  final String source;
  final TracePhase phase;
  final String detail;

  String get label => switch (phase) {
        TracePhase.start => 'start',
        TracePhase.loading => 'loading',
        TracePhase.data => 'data',
        TracePhase.error => 'error',
        TracePhase.call => 'call',
      };

  @override
  String toString() => '$label $source${detail.isEmpty ? '' : ' $detail'}';
}

/// In-memory execution log (newest first). Never persisted; frontend dev aid.
class ExecutionTraceController extends StateNotifier<List<TraceEntry>> {
  ExecutionTraceController() : super(const []);

  static const int _maxEntries = 200;

  void record(
    String source,
    TracePhase phase, {
    String detail = '',
  }) {
    if (source.isEmpty && detail.isEmpty) return;
    final entry = TraceEntry(
      time: DateTime.now(),
      source: source,
      phase: phase,
      detail: detail.length > 140 ? '${detail.substring(0, 140)}…' : detail,
    );
    final next = [entry, ...state];
    state = next.length > _maxEntries ? next.sublist(0, _maxEntries) : next;
  }

  void clear() => state = const [];
}

/// Exposes the trace recorder so any screen/provider (that holds a `ref`)
/// can record explicit logic executions.
final traceRecorderProvider =
    Provider<ExecutionTraceController>((ref) => ref.watch(executionTraceProvider.notifier));

final executionTraceProvider =
    StateNotifierProvider<ExecutionTraceController, List<TraceEntry>>(
        (ref) => ExecutionTraceController());

/// Records an explicit logic execution point (UI actions, service calls, ...).
/// Providers holding a `ref` should use [traceRecorderProvider] instead.
void traceLog(String source, TracePhase phase, {String detail = ''}) {
  debugPrint('[trace] ${TraceEntry(time: DateTime.now(), source: source, phase: phase, detail: detail)}');
}

/// Riverpod observer that records every async provider transition
/// (loading -> data/error) and non-async provider updates app-wide.
class ExecutionTraceObserver extends ProviderObserver {
  bool _recording = true;

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (!_recording) return;
    if (identical(provider, executionTraceProvider)) return;

    if (newValue is AsyncValue) {
      _record(container, provider, newValue);
    }
  }

  void _record(
    ProviderContainer container,
    ProviderBase<Object?> provider,
    AsyncValue<Object?> value,
  ) {
    if (value.isLoading) {
      record(
        container,
        provider,
        TracePhase.loading,
        value.valueOrNull?.toString() ?? '',
      );
      return;
    }
    if (value.hasError) {
      record(
        container,
        provider,
        TracePhase.error,
        value.error.toString(),
      );
      return;
    }
    record(
      container,
      provider,
      TracePhase.data,
      value.valueOrNull?.toString() ?? '',
    );
  }

  void record(
    ProviderContainer container,
    ProviderBase<Object?> provider,
    TracePhase phase,
    String detail,
  ) {
    // State is changed synchronously from the observer; isolate the trace
    // state update to avoid re-entrancy issues.
    _recording = false;
    try {
      container
          .read(executionTraceProvider.notifier)
          .record(provider.name ?? provider.runtimeType.toString(), phase,
              detail: detail);
    } catch (_) {
      // Trace must never break the app.
    } finally {
      _recording = true;
    }
  }
}