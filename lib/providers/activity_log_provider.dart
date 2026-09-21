import 'package:flutter/material.dart';
import '../models/activity_log.dart';
import '../services/pb_service.dart';

class ActivityLogProvider extends ChangeNotifier {
  final PBService _pb = PBService();
  List<ActivityLog> _logs = [];
  bool _isLoading = false;

  List<ActivityLog> get logs => _logs;
  bool get isLoading => _isLoading;

  Future<void> loadLogs({int limit = 50}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final records = await _pb.getActivityLogs(limit: limit);
      _logs = records.map((r) => ActivityLog.fromJson(r.toJson())).toList();
    } catch (_) {
      _logs = [];
    }

    _isLoading = false;
    notifyListeners();
  }
}
