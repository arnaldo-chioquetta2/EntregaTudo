import 'package:flutter/foundation.dart';

class WebDebugLogService extends ChangeNotifier {
  WebDebugLogService._();

  static final WebDebugLogService instance = WebDebugLogService._();

  final List<String> _logs = [];

  List<String> get logs => List.unmodifiable(_logs);

  String get text => _logs.join('\n');

  void add(String message) {
    if (!kIsWeb) return;
    _logs.add('${DateTime.now().toIso8601String()} $message');
    if (_logs.length > 50) {
      _logs.removeRange(0, _logs.length - 50);
    }
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
