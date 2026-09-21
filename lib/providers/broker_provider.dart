import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../models/broker.dart';
import '../services/pb_service.dart';

class BrokerProvider extends ChangeNotifier {
  final PBService _pb = PBService();
  List<Broker> _brokers = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  // In-flight request guard to prevent duplicate concurrent loads.
  Future<void>? _inflight;

  List<Broker> get brokers => _brokers;
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  /// Loads brokers + balances efficiently:
  ///   - 1 request for brokers
  ///   - 1 parallel call that internally does 2 small requests for all balances
  ///   - balances are merged in-memory in O(N)
  ///
  /// Total: 3 requests to the server regardless of how many brokers exist
  /// (down from 1 + 2*N).
  Future<void> loadBrokers({bool silent = false}) async {
    // Re-use the same in-flight future so multiple callers don't thrash the server.
    if (_inflight != null) return _inflight!;
    final future = _loadBrokersInternal(silent: silent);
    _inflight = future;
    try {
      await future;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _loadBrokersInternal({required bool silent}) async {
    if (!silent || !_hasLoadedOnce) {
      _isLoading = true;
      _error = null;
      // Avoid notify-during-build; microtask defers to after frame.
      Future.microtask(() {
        if (_isLoading) notifyListeners();
      });
    }

    try {
      // Run brokers list + all balances in parallel.
      final results = await Future.wait([
        _pb.getBrokers(),
        _pb.getAllBrokerBalances(),
      ]);

      final records = results[0] as List<RecordModel>;
      final balances = results[1] as Map<String, Map<String, double>>;

      final list = List<Broker>.generate(records.length, (i) {
        final r = records[i];
        final json = r.toJson();
        final imageFilename = json['image'];
        if (imageFilename != null && imageFilename.toString().isNotEmpty) {
          json['image_url'] = _pb.pb.files
              .getUrl(r, imageFilename.toString(), query: {'thumb': '80x80'})
              .toString();
        }
        final b = Broker.fromJson(json);
        final bal = balances[b.id];
        if (bal != null) {
          b.totalDebt = bal['total_debt'] ?? 0;
          b.totalPaid = bal['total_paid'] ?? 0;
        }
        return b;
      });

      _brokers = list;
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    } catch (e) {
      _error = 'هەڵە لە بارکردنی بریکارەکان';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Only loads if we haven't loaded yet; otherwise no-op.
  Future<void> ensureLoaded() async {
    if (_hasLoadedOnce || _inflight != null) return;
    await loadBrokers();
  }

  Future<bool> addBroker({
    required String name,
    required String phone,
    String? companyName,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'company_name': companyName ?? '',
        'created_by': _pb.currentUserName ?? '',
      };

      if (imageBytes != null) {
        await _pb.pb.collection('brokers').create(
          body: body,
          files: [
            http.MultipartFile.fromBytes('image', imageBytes,
                filename: imageName ?? 'image.jpg'),
          ],
        );
      } else {
        await _pb.createBroker(body);
      }

      // Fire-and-forget log; don't block user on it.
      unawaited(_pb.logActivity(
        actionType: 'create',
        entityType: 'broker',
        description: 'بریکاری "$name" زیادکرا',
      ));

      // Silent refresh — realtime may also trigger one; in-flight guard handles it.
      unawaited(loadBrokers(silent: true));
      return true;
    } catch (e) {
      _error = 'هەڵە لە زیادکردنی بریکار';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBroker({
    required String id,
    required String name,
    required String phone,
    String? companyName,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'company_name': companyName ?? '',
      };

      if (imageBytes != null) {
        await _pb.pb.collection('brokers').update(
          id,
          body: body,
          files: [
            http.MultipartFile.fromBytes('image', imageBytes,
                filename: imageName ?? 'image.jpg'),
          ],
        );
      } else {
        await _pb.updateBroker(id, body);
      }

      unawaited(_pb.logActivity(
        actionType: 'update',
        entityType: 'broker',
        entityId: id,
        description: 'بریکاری "$name" نوێکرایەوە',
      ));

      unawaited(loadBrokers(silent: true));
      return true;
    } catch (e) {
      _error = 'هەڵە لە نوێکردنەوەی بریکار';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBroker(String id) async {
    try {
      final broker = _brokers.where((b) => b.id == id).firstOrNull;
      // Optimistic removal for instant UI feedback.
      _brokers = _brokers.where((b) => b.id != id).toList();
      notifyListeners();

      await _pb.deleteBroker(id);
      unawaited(_pb.logActivity(
        actionType: 'delete',
        entityType: 'broker',
        entityId: id,
        description: 'بریکاری "${broker?.name ?? id}" سڕایەوە',
      ));

      unawaited(loadBrokers(silent: true));
      return true;
    } catch (e) {
      _error = 'هەڵە لە سڕینەوەی بریکار';
      // Rollback optimistic removal via reload.
      unawaited(loadBrokers(silent: true));
      notifyListeners();
      return false;
    }
  }

  String getBrokerImageUrl(RecordModel record) {
    final filename = record.data['image'];
    if (filename == null || filename.toString().isEmpty) return '';
    return _pb.getFileUrl(record, filename.toString());
  }
}
