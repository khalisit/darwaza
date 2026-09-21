import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PBService {
  static final PBService _instance = PBService._internal();
  factory PBService() => _instance;
  PBService._internal();

  late PocketBase pb;
  bool _initialized = false;

  // Current user info
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;

  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  String? get currentUserRole => _currentUserRole;
  bool get isAdmin => _currentUserRole == 'admin';

  // ---- Item prices in-memory cache (refreshed on upsert) ----
  List<RecordModel>? _itemPricesCache;
  DateTime? _itemPricesCacheAt;
  static const Duration _itemPricesTtl = Duration(minutes: 10);

  /// Call ONCE from main() before runApp — synchronously restores auth.
  void initSync(SharedPreferences prefs) {
    if (_initialized) return;
    const defaultUrl = 'https://marketdarwaza.duckdns.org';
    // Always use the default VPS URL — clear any old cached URL
    final savedUrl = prefs.getString('server_url');
    if (savedUrl != null && savedUrl != defaultUrl) {
      prefs.remove('server_url');
    }
    final serverUrl = defaultUrl;

    final store = AsyncAuthStore(
      save: (data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
      clear: () async => prefs.remove('pb_auth'),
    );

    pb = PocketBase(serverUrl, authStore: store);

    // Migrate from old manual keys (one-time)
    if (!pb.authStore.isValid) {
      final oldToken = prefs.getString('pb_token');
      final oldModel = prefs.getString('pb_model');
      if (oldToken != null && oldModel != null) {
        try {
          pb.authStore.save(oldToken, jsonDecode(oldModel));
        } catch (_) {}
        prefs.remove('pb_token');
        prefs.remove('pb_model');
      }
    } else {
      // Clean up old keys if present
      prefs.remove('pb_token');
      prefs.remove('pb_model');
    }

    if (pb.authStore.isValid) {
      _extractUserInfo();
    }
    _initialized = true;
  }

  /// Background refresh — call after UI is up.
  Future<void> tryRefreshAuth() async {
    if (!pb.authStore.isValid) return;
    try {
      final auth = await pb.collection('users').authRefresh();
      final isActive = auth.record.data['active'] ?? true;
      if (isActive == false) {
        await logout();
        return;
      }
      _extractUserInfo();
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('403')) {
        await logout();
      }
    }
  }

  /// Subscribe to the current user's record for realtime active-status changes.
  void subscribeCurrentUser(void Function() onDeactivated) {
    final uid = _currentUserId;
    if (uid == null) return;
    pb.collection('users').subscribe(uid, (e) {
      if (e.action == 'update') {
        final active = e.record?.data['active'] ?? true;
        if (active == false) {
          onDeactivated();
        }
      }
    });
  }

  void unsubscribeCurrentUser() {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      pb.collection('users').unsubscribe(uid);
    } catch (_) {}
  }

  void _extractUserInfo() {
    if (pb.authStore.isValid && pb.authStore.record != null) {
      final record = pb.authStore.record!;
      _currentUserId = record.id;
      _currentUserName = record.data['name']?.toString() ??
          record.data['username']?.toString() ??
          record.data['email']?.toString() ??
          'بێناو';
      _currentUserRole = record.data['role']?.toString() ?? 'user';
    }
  }

  bool get isLoggedIn => pb.authStore.isValid;

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    final store = AsyncAuthStore(
      save: (data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
      clear: () async => prefs.remove('pb_auth'),
    );
    pb = PocketBase(url, authStore: store);
  }

  /// Login result: 'ok', 'deactivated', or 'error'.
  Future<String> login(String email, String password) async {
    try {
      final auth = await pb.collection('users').authWithPassword(email, password);
      final isActive = auth.record.data['active'] ?? true;
      if (isActive == false) {
        pb.authStore.clear();
        return 'deactivated';
      }
      _extractUserInfo();
      return 'ok';
    } catch (e) {
      return 'error';
    }
  }

  Future<void> logout() async {
    pb.authStore.clear();
    _currentUserId = null;
    _currentUserName = null;
    _currentUserRole = null;
    _itemPricesCache = null;
    _itemPricesCacheAt = null;
  }

  // ---- Brokers ----
  Future<List<RecordModel>> getBrokers() async {
    // Only pull the fields we actually render — cuts payload drastically.
    return await pb.collection('brokers').getFullList(
          sort: '-created',
          fields:
              'id,name,phone,company_name,image,created_by,created,updated,collectionId,collectionName',
        );
  }

  Future<RecordModel> createBroker(Map<String, dynamic> data) async {
    return await pb.collection('brokers').create(body: data);
  }

  Future<RecordModel> updateBroker(String id, Map<String, dynamic> data) async {
    return await pb.collection('brokers').update(id, body: data);
  }

  Future<void> deleteBroker(String id) async {
    await pb.collection('brokers').delete(id);
  }

  // ---- Transactions ----
  Future<List<RecordModel>> getTransactions({String? brokerId}) async {
    String? filter;
    if (brokerId != null) {
      filter = 'broker_id = "$brokerId"';
    }
    final records = await pb.collection('transactions').getFullList(
          sort: '-created',
          filter: filter,
        );
    return records;
  }

  Future<ResultList<RecordModel>> getTransactionsPaginated({
    String? brokerId,
    int page = 1,
    int perPage = 20,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
  }) async {
    final filters = <String>[];
    if (brokerId != null) {
      filters.add('broker_id = "$brokerId"');
    }
    if (dateFrom != null) {
      filters.add('transaction_date >= "${dateFrom.toUtc().toIso8601String()}"');
    }
    if (dateTo != null) {
      final end = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
      filters.add('transaction_date <= "${end.toUtc().toIso8601String()}"');
    }
    if (search != null && search.isNotEmpty) {
      filters.add('(partner_name ~ "$search" || notes ~ "$search")');
    }
    final filter = filters.isNotEmpty ? filters.join(' && ') : null;
    return await pb.collection('transactions').getList(
          page: page,
          perPage: perPage,
          sort: '-transaction_date',
          filter: filter,
        );
  }

  Future<RecordModel> createTransaction(Map<String, dynamic> data) async {
    return await pb.collection('transactions').create(body: data);
  }

  Future<RecordModel> updateTransaction(String id, Map<String, dynamic> data) async {
    return await pb.collection('transactions').update(id, body: data);
  }

  Future<void> deleteTransaction(String id) async {
    await pb.collection('transactions').delete(id);
  }

  // ---- Transaction Items ----
  Future<List<RecordModel>> getTransactionItems(String transactionId) async {
    final records = await pb.collection('transaction_items').getFullList(
          filter: 'transaction_id = "$transactionId"',
          sort: '-created',
        );
    return records;
  }

  Future<RecordModel> createTransactionItem(Map<String, dynamic> data) async {
    return await pb.collection('transaction_items').create(body: data);
  }

  Future<RecordModel> updateTransactionItem(String id, Map<String, dynamic> data) async {
    return await pb.collection('transaction_items').update(id, body: data);
  }

  Future<void> deleteTransactionItem(String id) async {
    await pb.collection('transaction_items').delete(id);
  }

  Future<List<RecordModel>> getAllTransactionItems() async {
    return await pb.collection('transaction_items').getFullList(sort: '-created');
  }

  // ---- Item Prices (sell prices) ----
  Future<List<RecordModel>> getAllItemPrices({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _itemPricesCache != null &&
        _itemPricesCacheAt != null &&
        DateTime.now().difference(_itemPricesCacheAt!) < _itemPricesTtl) {
      return _itemPricesCache!;
    }
    final list =
        await pb.collection('item_prices').getFullList(sort: 'item_prices');
    _itemPricesCache = list;
    _itemPricesCacheAt = DateTime.now();
    return list;
  }

  void invalidateItemPricesCache() {
    _itemPricesCache = null;
    _itemPricesCacheAt = null;
  }

  Future<RecordModel?> getItemPrice(String itemName) async {
    try {
      final all = await getAllItemPrices();
      final trimmed = itemName.trim();
      final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
      for (final r in all) {
        final stored = r.getStringValue('item_prices').trim();
        if (stored == trimmed ||
            stored.replaceAll(RegExp(r'\s+'), ' ') == normalized) {
          return r;
        }
      }
      return null;
    } catch (e) {
      debugPrint('getItemPrice error: $e');
      return null;
    }
  }

  Future<RecordModel> upsertItemPrice({
    required String itemName,
    required double sellPrice,
    String unit = '',
    String note = '',
  }) async {
    final trimmedName = itemName.trim();
    final body = {
      'item_prices': trimmedName,
      'sell_price': sellPrice,
      'unit': unit,
      'note': note,
    };

    final existing = await getItemPrice(trimmedName);
    if (existing != null) {
      final updated =
          await pb.collection('item_prices').update(existing.id, body: body);
      invalidateItemPricesCache();
      return updated;
    }

    try {
      final created = await pb.collection('item_prices').create(body: body);
      invalidateItemPricesCache();
      return created;
    } catch (_) {
      // Unique constraint hit — bust cache then look up again
      invalidateItemPricesCache();
      final all = await getAllItemPrices(forceRefresh: true);
      for (final r in all) {
        if (r.getStringValue('item_prices').trim() == trimmedName) {
          final updated =
              await pb.collection('item_prices').update(r.id, body: body);
          invalidateItemPricesCache();
          return updated;
        }
      }
      for (final r in all) {
        final stored = r.getStringValue('item_prices').trim();
        if (stored.contains(trimmedName) || trimmedName.contains(stored)) {
          final updated =
              await pb.collection('item_prices').update(r.id, body: body);
          invalidateItemPricesCache();
          return updated;
        }
      }
      rethrow;
    }
  }

  Future<void> deleteItemPrice(String id) async {
    await pb.collection('item_prices').delete(id);
    invalidateItemPricesCache();
  }

  // ---- Receipts ----
  Future<List<RecordModel>> getReceipts(String transactionId) async {
    final records = await pb.collection('receipts').getFullList(
          filter: 'transaction_id = "$transactionId"',
          sort: '-created',
        );
    return records;
  }

  Future<RecordModel> uploadReceipt(
      String transactionId, Uint8List bytes, String filename) async {
    return await pb.collection('receipts').create(
      body: {'transaction_id': transactionId},
      files: [http.MultipartFile.fromBytes('image', bytes, filename: filename)],
    );
  }

  Future<void> deleteReceipt(String id) async {
    await pb.collection('receipts').delete(id);
  }

  String getFileUrl(RecordModel record, String filename) {
    return pb.files.getUrl(record, filename).toString();
  }

  String getPaymentFileUrl(String collectionId, String recordId, String filename) {
    return '${pb.baseURL}/api/files/$collectionId/$recordId/$filename';
  }

  // ---- Payments ----
  Future<List<RecordModel>> getPayments({String? brokerId}) async {
    String? filter;
    if (brokerId != null) {
      filter = 'broker_id = "$brokerId"';
    }
    final records = await pb.collection('payments').getFullList(
          sort: '-created',
          filter: filter,
        );
    return records;
  }

  Future<RecordModel> createPayment(Map<String, dynamic> data,
      {List<http.MultipartFile>? files}) async {
    return await pb.collection('payments').create(body: data, files: files ?? []);
  }

  Future<RecordModel> updatePayment(String id, Map<String, dynamic> data) async {
    return await pb.collection('payments').update(id, body: data);
  }

  Future<void> deletePayment(String id) async {
    await pb.collection('payments').delete(id);
  }

  // ---- Activity Logs ----
  Future<List<RecordModel>> getActivityLogs({int limit = 50}) async {
    // Use pagination to ONLY fetch the first `limit` records.
    final result = await pb.collection('activity_logs').getList(
          page: 1,
          perPage: limit,
          sort: '-created',
        );
    return result.items;
  }

  Future<void> logActivity({
    required String actionType,
    required String entityType,
    String? entityId,
    required String description,
  }) async {
    try {
      await pb.collection('activity_logs').create(body: {
        'user_id': _currentUserId ?? '',
        'user_name': _currentUserName ?? 'بێناو',
        'action_type': actionType,
        'entity_type': entityType,
        'entity_id': entityId ?? '',
        'description': description,
      });
    } catch (_) {
      // Don't let logging failures break the app
    }
  }

  // ---- Broker Balances (BATCH) ----
  /// Efficiently computes balances for ALL brokers.
  ///
  /// Strategy:
  ///   1. Try the server-side custom endpoint `/api/custom/broker-balances`
  ///      which does the aggregation in one SQL query. This is the fastest
  ///      path — 1 tiny request regardless of data size.
  ///   2. If the hook isn't installed (404) or anything goes wrong, fall
  ///      back to the client-side aggregation below (2 parallel requests).
  ///
  /// Returns map: brokerId -> {total_debt, total_paid, balance}.
  bool _customBalancesEndpointUnavailable = false;

  Future<Map<String, Map<String, double>>> getAllBrokerBalances() async {
    if (!_customBalancesEndpointUnavailable) {
      try {
        final uri = Uri.parse('${pb.baseURL}/api/custom/broker-balances');
        final resp = await http.get(
          uri,
          headers: {
            'Authorization': pb.authStore.token,
            'Accept-Encoding': 'gzip',
          },
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          final out = <String, Map<String, double>>{};
          decoded.forEach((brokerId, value) {
            final m = value as Map<String, dynamic>;
            out[brokerId] = {
              'total_debt': (m['total_debt'] ?? 0).toDouble(),
              'total_paid': (m['total_paid'] ?? 0).toDouble(),
              'balance': (m['balance'] ?? 0).toDouble(),
            };
          });
          return out;
        }
        if (resp.statusCode == 404) {
          // Hook not installed; don't try again this session.
          _customBalancesEndpointUnavailable = true;
        }
      } catch (_) {
        // Fall through to client-side aggregation.
      }
    }

    // Fallback: 2 parallel requests + client-side aggregation.
    final results = await Future.wait([
      pb.collection('transactions').getFullList(
            fields: 'broker_id,total_amount,discount,final_amount',
          ),
      pb.collection('payments').getFullList(
            fields: 'broker_id,amount',
          ),
    ]);

    final transactions = results[0];
    final payments = results[1];

    final debtByBroker = <String, double>{};
    for (final t in transactions) {
      final brokerId = t.data['broker_id']?.toString() ?? '';
      if (brokerId.isEmpty) continue;
      final finalAmt = (t.data['final_amount'] ?? 0);
      double value;
      if (finalAmt is num && finalAmt != 0) {
        value = finalAmt.toDouble();
      } else {
        final total = (t.data['total_amount'] ?? 0).toDouble();
        final disc = (t.data['discount'] ?? 0).toDouble();
        value = total - disc;
      }
      debtByBroker[brokerId] = (debtByBroker[brokerId] ?? 0) + value;
    }

    final paidByBroker = <String, double>{};
    for (final p in payments) {
      final brokerId = p.data['broker_id']?.toString() ?? '';
      if (brokerId.isEmpty) continue;
      paidByBroker[brokerId] =
          (paidByBroker[brokerId] ?? 0) + (p.data['amount'] ?? 0).toDouble();
    }

    final brokerIds = <String>{...debtByBroker.keys, ...paidByBroker.keys};
    final out = <String, Map<String, double>>{};
    for (final id in brokerIds) {
      final debt = debtByBroker[id] ?? 0;
      final paid = paidByBroker[id] ?? 0;
      out[id] = {
        'total_debt': debt,
        'total_paid': paid,
        'balance': debt - paid,
      };
    }
    return out;
  }

  /// Single-broker balance — still uses the batch endpoint result
  /// but scoped via filter so it's fast.
  Future<Map<String, double>> getBrokerBalance(String brokerId) async {
    final results = await Future.wait([
      pb.collection('transactions').getFullList(
            filter: 'broker_id = "$brokerId"',
            fields: 'total_amount,discount,final_amount',
          ),
      pb.collection('payments').getFullList(
            filter: 'broker_id = "$brokerId"',
            fields: 'amount',
          ),
    ]);

    double totalDebt = 0;
    for (final t in results[0]) {
      final finalAmt = (t.data['final_amount'] ?? 0);
      if (finalAmt is num && finalAmt != 0) {
        totalDebt += finalAmt.toDouble();
      } else {
        final total = (t.data['total_amount'] ?? 0).toDouble();
        final disc = (t.data['discount'] ?? 0).toDouble();
        totalDebt += (total - disc);
      }
    }

    double totalPaid = 0;
    for (final p in results[1]) {
      totalPaid += (p.data['amount'] ?? 0).toDouble();
    }

    return {
      'total_debt': totalDebt,
      'total_paid': totalPaid,
      'balance': totalDebt - totalPaid,
    };
  }

  // ---- Users Management (Admin only) ----
  Future<List<RecordModel>> getUsers() async {
    final records = await pb.collection('users').getFullList(sort: '-created');
    return records;
  }

  Future<RecordModel> createUser({
    required String email,
    required String password,
    required String name,
    String role = 'user',
  }) async {
    return await pb.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'name': name,
      'role': role,
      'active': true,
    });
  }

  Future<RecordModel> updateUser(String id, Map<String, dynamic> data) async {
    return await pb.collection('users').update(id, body: data);
  }

  Future<void> toggleUserActive(String id, bool active) async {
    await pb.collection('users').update(id, body: {'active': active});
  }

  Future<void> resetUserPassword(String id, String newPassword) async {
    await pb.collection('users').update(id, body: {
      'password': newPassword,
      'passwordConfirm': newPassword,
    });
  }

  Future<void> deleteUser(String id) async {
    await pb.collection('users').delete(id);
  }

  /// Permanently deletes the currently signed-in user account.
  Future<void> deleteOwnAccount() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');

    unsubscribeCurrentUser();
    await pb.collection('users').delete(userId);
    await logout();
  }

  // ---- Change Own Password ----
  Future<void> changeOwnPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not logged in');

    final email = pb.authStore.record?.data['email']?.toString();
    if (email == null) throw Exception('No email found');

    await pb.collection('users').update(userId, body: {
      'oldPassword': oldPassword,
      'password': newPassword,
      'passwordConfirm': newPassword,
    });

    final auth =
        await pb.collection('users').authWithPassword(email, newPassword);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pb_token', pb.authStore.token);
    await prefs.setString('pb_model', jsonEncode(auth.record.toJson()));
    _extractUserInfo();
  }
}
