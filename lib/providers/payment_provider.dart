import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/payment.dart';
import '../services/pb_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PBService _pb = PBService();
  List<Payment> _payments = [];
  bool _isLoading = false;
  String? _error;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPayments({String? brokerId}) async {
    _isLoading = true;
    _error = null;
    Future.microtask(() {
      if (_isLoading) notifyListeners();
    });

    try {
      final records = await _pb.getPayments(brokerId: brokerId);
      _payments = records.map((r) => Payment.fromJson(r.toJson())).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'هەڵە لە بارکردنی پارەدانەکان';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addPayment({
    required String brokerId,
    required double amount,
    required DateTime paymentDate,
    String? notes,
    List<XFile>? receiptImages,
  }) async {
    try {
      List<http.MultipartFile>? files;
      if (receiptImages != null && receiptImages.isNotEmpty) {
        final bytes = await receiptImages.first.readAsBytes();
        files = [
          http.MultipartFile.fromBytes('receipt', bytes,
              filename: receiptImages.first.name),
        ];
      }
      await _pb.createPayment({
        'broker_id': brokerId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String(),
        'notes': notes ?? '',
        'created_by': _pb.currentUserName ?? '',
      }, files: files);

      unawaited(_pb.logActivity(
        actionType: 'payment',
        entityType: 'payment',
        description:
            'پارەدانی ${amount.toStringAsFixed(0)} د.ع تۆمارکرا (لە لایەن: ${_pb.currentUserName ?? ''})',
      ));

      // Realtime subscription refreshes the list; no blocking reload here.
      return true;
    } catch (e) {
      debugPrint('Payment error: $e');
      _error = 'هەڵە لە زیادکردنی پارەدان';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePayment({
    required String id,
    required String brokerId,
    required double amount,
    required DateTime paymentDate,
    String? notes,
  }) async {
    try {
      await _pb.updatePayment(id, {
        'broker_id': brokerId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String(),
        'notes': notes ?? '',
      });
      return true;
    } catch (e) {
      _error = 'هەڵە لە نوێکردنەوەی پارەدان';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePayment(String id, {String? brokerId}) async {
    try {
      // Optimistic local removal.
      _payments = _payments.where((p) => p.id != id).toList();
      notifyListeners();

      await _pb.deletePayment(id);
      unawaited(_pb.logActivity(
        actionType: 'delete',
        entityType: 'payment',
        entityId: id,
        description: 'پارەدانێک سڕایەوە',
      ));
      return true;
    } catch (e) {
      _error = 'هەڵە لە سڕینەوەی پارەدان';
      unawaited(loadPayments(brokerId: brokerId));
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, double>> getBrokerBalance(String brokerId) async {
    return await _pb.getBrokerBalance(brokerId);
  }

  String? getPaymentReceiptUrl(Payment payment) {
    if (payment.receipt == null || payment.receipt!.isEmpty) return null;
    if (payment.collectionId == null) return null;
    return _pb.getPaymentFileUrl(
        payment.collectionId!, payment.id, payment.receipt!);
  }
}
