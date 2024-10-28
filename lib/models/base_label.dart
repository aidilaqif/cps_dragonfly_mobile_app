class BaseLabel {
  final DateTime timeLog;
  final bool isRescan;
  final String? sessionId;
  final Map<String, dynamic>? metadata;

  BaseLabel({
    required this.timeLog,
    this.isRescan = false,
    this.sessionId,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'timelog': timeLog.toIso8601String(),
      'is_rescan': isRescan,
      'session_id': sessionId,
      'metadata': metadata,
    };
  }
}