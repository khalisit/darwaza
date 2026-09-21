class Transaction {
  final String id;
  final String brokerId;
  final double totalAmount;
  final double discount;
  final double finalAmount;
  final bool isCredit;
  final String? notes;
  final String? partnerName;
  final String? createdBy;
  final DateTime transactionDate;
  final DateTime created;
  final DateTime updated;
  List<TransactionItem> items;
  List<String> receiptUrls;

  Transaction({
    required this.id,
    required this.brokerId,
    required this.totalAmount,
    this.discount = 0,
    double? finalAmount,
    required this.isCredit,
    this.notes,
    this.partnerName,
    this.createdBy,
    DateTime? transactionDate,
    required this.created,
    required this.updated,
    this.items = const [],
    this.receiptUrls = const [],
  }) : finalAmount = finalAmount ?? (totalAmount - (discount)),
       transactionDate = transactionDate ?? created;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final total = (json['total_amount'] ?? 0).toDouble();
    final disc = (json['discount'] ?? 0).toDouble();
    final created = DateTime.tryParse(json['created'] ?? '') ?? DateTime.now();
    return Transaction(
      id: json['id'] ?? '',
      brokerId: json['broker_id'] ?? '',
      totalAmount: total,
      discount: disc,
      finalAmount: total - disc,
      isCredit: json['is_credit'] ?? false,
      notes: json['notes'],
      partnerName: json['partner_name'],
      createdBy: json['created_by'],
      transactionDate: DateTime.tryParse(json['transaction_date'] ?? '') ?? created,
      created: created,
      updated: DateTime.tryParse(json['updated'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'broker_id': brokerId,
      'total_amount': totalAmount,
      'discount': discount,
      'final_amount': finalAmount,
      'is_credit': isCredit,
      'notes': notes,
      'partner_name': partnerName ?? '',
      'transaction_date': transactionDate.toIso8601String(),
      'created_by': createdBy ?? '',
    };
  }
}

class TransactionItem {
  final String id;
  final String transactionId;
  final String itemName;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  TransactionItem({
    required this.id,
    required this.transactionId,
    required this.itemName,
    required this.quantity,
    this.unit = 'دانە',
    required this.unitPrice,
    required this.totalPrice,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      itemName: json['item_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? 'دانە',
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  TransactionItem copyWith({
    String? id,
    String? transactionId,
    String? itemName,
    int? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}
