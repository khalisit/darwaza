import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/transaction.dart';
import '../services/pb_service.dart';
import '../core/theme.dart';

String formatNum(double v) => formatMoney(v);

class TransactionProvider extends ChangeNotifier {
  final PBService _pb = PBService();
  List<Transaction> _transactions = [];
  List<TransactionItem> _currentItems = [];
  bool _isLoading = false;
  String? _error;

  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _perPage = 20;

  List<Transaction> get transactions => _transactions;
  List<TransactionItem> get currentItems => _currentItems;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  // Last-used filter params for realtime refresh
  String? _lastBrokerId;
  DateTime? _lastDateFrom;
  DateTime? _lastDateTo;
  String? _lastSearch;

  Future<void> loadTransactions({String? brokerId}) async {
    _isLoading = true;
    _error = null;
    Future.microtask(() {
      if (_isLoading) notifyListeners();
    });

    try {
      final records = await _pb.getTransactions(brokerId: brokerId);
      _transactions =
          records.map((r) => Transaction.fromJson(r.toJson())).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'هەڵە لە بارکردنی کڕینەکان';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactionsPaginated({
    String? brokerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _transactions = [];
      _lastBrokerId = brokerId;
      _lastDateFrom = dateFrom;
      _lastDateTo = dateTo;
      _lastSearch = search;
    }

    if (!_hasMore && !refresh) return;

    if (_currentPage == 1) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _error = null;
    Future.microtask(() {
      if (_isLoading || _isLoadingMore) notifyListeners();
    });

    try {
      final result = await _pb.getTransactionsPaginated(
        brokerId: brokerId,
        page: _currentPage,
        perPage: _perPage,
        dateFrom: dateFrom,
        dateTo: dateTo,
        search: search,
      );
      final newItems =
          result.items.map((r) => Transaction.fromJson(r.toJson())).toList();

      if (refresh || _currentPage == 1) {
        _transactions = newItems;
      } else {
        _transactions.addAll(newItems);
      }

      _totalPages = result.totalPages;
      _hasMore = _currentPage < _totalPages;
      _currentPage++;
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _error = 'هەڵە لە بارکردنی کڕینەکان';
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void resetPagination() {
    _currentPage = 1;
    _totalPages = 1;
    _hasMore = true;
    _transactions = [];
  }

  Future<void> refreshCurrent() async {
    await loadTransactionsPaginated(
      brokerId: _lastBrokerId,
      dateFrom: _lastDateFrom,
      dateTo: _lastDateTo,
      search: _lastSearch,
      refresh: true,
    );
  }

  Future<void> loadTransactionItems(String transactionId) async {
    try {
      final records = await _pb.getTransactionItems(transactionId);
      _currentItems =
          records.map((r) => TransactionItem.fromJson(r.toJson())).toList();
      notifyListeners();
    } catch (e) {
      _error = 'هەڵە لە بارکردنی ئایتمەکان';
      notifyListeners();
    }
  }

  Future<String?> createTransaction({
    required String brokerId,
    required bool isCredit,
    String? notes,
    String? partnerName,
    double discount = 0,
    DateTime? transactionDate,
    required List<Map<String, dynamic>> items,
    double? totalAmount,
  }) async {
    try {
      double computedTotal = totalAmount ?? 0;
      if (items.isNotEmpty && totalAmount == null) {
        computedTotal = 0;
        for (final item in items) {
          computedTotal +=
              (item['quantity'] as int) * (item['unit_price'] as double);
        }
      }
      final finalAmount = computedTotal - discount;

      final transaction = await _pb.createTransaction({
        'broker_id': brokerId,
        'total_amount': computedTotal,
        'discount': discount,
        'final_amount': finalAmount,
        'is_credit': isCredit,
        'notes': notes ?? '',
        'partner_name': partnerName ?? '',
        'transaction_date':
            (transactionDate ?? DateTime.now()).toIso8601String(),
        'created_by': _pb.currentUserName ?? '',
      });

      // Create all items in PARALLEL — huge speedup for multi-item transactions.
      if (items.isNotEmpty) {
        await Future.wait(items.map((item) {
          final qty = item['quantity'] as int;
          final price = item['unit_price'] as double;
          return _pb.createTransactionItem({
            'transaction_id': transaction.id,
            'item_name': item['item_name'],
            'quantity': qty,
            'unit': item['unit'] ?? 'دانە',
            'unit_price': price,
            'total_price': qty * price,
          });
        }));
      }

      // Fire-and-forget activity log; don't block the user.
      unawaited(_pb.logActivity(
        actionType: 'create',
        entityType: 'transaction',
        entityId: transaction.id,
        description:
            'کڕینی نوێ بە بڕی ${formatNum(finalAmount)} د.ع ${isCredit ? "(قەرز)" : "(نەقد)"}',
      ));

      // NOTE: intentionally NOT calling loadTransactions here.
      // Realtime subscription will refresh the lists; the caller can refresh
      // locally if they need immediate feedback.
      return transaction.id;
    } catch (e) {
      _error = 'هەڵە لە دروستکردنی کڕین';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTransaction({
    required String id,
    required String brokerId,
    required bool isCredit,
    String? notes,
    String? partnerName,
    double discount = 0,
    DateTime? transactionDate,
    required List<Map<String, dynamic>> items,
    double? totalAmount,
  }) async {
    try {
      double computedTotal = totalAmount ?? 0;
      if (items.isNotEmpty && totalAmount == null) {
        computedTotal = 0;
        for (final item in items) {
          computedTotal +=
              (item['quantity'] as int) * (item['unit_price'] as double);
        }
      }
      final finalAmount = computedTotal - discount;

      await _pb.updateTransaction(id, {
        'broker_id': brokerId,
        'total_amount': computedTotal,
        'discount': discount,
        'final_amount': finalAmount,
        'is_credit': isCredit,
        'notes': notes ?? '',
        'partner_name': partnerName ?? '',
        'transaction_date':
            (transactionDate ?? DateTime.now()).toIso8601String(),
      });

      // Delete old items and create new ones in PARALLEL.
      final oldItems = await _pb.getTransactionItems(id);
      await Future.wait(
          oldItems.map((old) => _pb.deleteTransactionItem(old.id)));

      if (items.isNotEmpty) {
        await Future.wait(items.map((item) {
          final qty = item['quantity'] as int;
          final price = item['unit_price'] as double;
          return _pb.createTransactionItem({
            'transaction_id': id,
            'item_name': item['item_name'],
            'quantity': qty,
            'unit': item['unit'] ?? 'دانە',
            'unit_price': price,
            'total_price': qty * price,
          });
        }));
      }

      return true;
    } catch (e) {
      _error = 'هەڵە لە نوێکردنەوەی کڕین';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String id, {String? brokerId}) async {
    try {
      // Optimistic removal from local list for instant UI.
      final prev = _transactions;
      _transactions = _transactions.where((t) => t.id != id).toList();
      notifyListeners();

      // Run deletes for items + receipts in PARALLEL.
      final futures = <Future>[];
      final items = await _pb.getTransactionItems(id);
      futures.addAll(items.map((i) => _pb.deleteTransactionItem(i.id)));

      final receipts = await _pb.getReceipts(id);
      futures.addAll(receipts.map((r) => _pb.deleteReceipt(r.id)));

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      await _pb.deleteTransaction(id);

      unawaited(_pb.logActivity(
        actionType: 'delete',
        entityType: 'transaction',
        entityId: id,
        description: 'کڕینێک سڕایەوە',
      ));

      // Don't crash if optimistic removal was inconsistent.
      if (prev.length == _transactions.length) {
        // No-op; already consistent.
      }
      return true;
    } catch (e) {
      _error = 'هەڵە لە سڕینەوەی کڕین';
      // Reload to recover from any inconsistency.
      unawaited(loadTransactions(brokerId: brokerId));
      notifyListeners();
      return false;
    }
  }

  // ---- Receipts ----
  Future<bool> uploadReceipt(
      String transactionId, Uint8List bytes, String filename) async {
    try {
      await _pb.uploadReceipt(transactionId, bytes, filename);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'هەڵە لە بارکردنی وەصڵ';
      notifyListeners();
      return false;
    }
  }

  Future<List<RecordModel>> getReceipts(String transactionId) async {
    return await _pb.getReceipts(transactionId);
  }

  String getReceiptUrl(RecordModel record) {
    final filename = record.data['image'];
    if (filename == null || filename.toString().isEmpty) return '';
    return _pb.getFileUrl(record, filename.toString());
  }
}
