import 'package:flutter/foundation.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<String> _logs = [];
  VoidCallback? _onLogAdded;

  List<String> get logs => List.unmodifiable(_logs);

  void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = '[$timestamp] $message';
    _logs.add(logLine);
    if (_logs.length > 150) {
      _logs.removeAt(0);
    }
    debugPrint(logLine);
    if (_onLogAdded != null) {
      _onLogAdded!();
    }
  }

  void setListener(VoidCallback listener) {
    _onLogAdded = listener;
  }

  void clearListener() {
    _onLogAdded = null;
  }

  void clearLogs() {
    _logs.clear();
    if (_onLogAdded != null) {
      _onLogAdded!();
    }
  }
}
