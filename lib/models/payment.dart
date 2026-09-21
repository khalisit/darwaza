class Payment {
  final String id;
  final String brokerId;
  final double amount;
  final DateTime paymentDate;
  final String? notes;
  final String? createdBy;
  final String? receipt;
  final String? collectionId;
  final DateTime created;
  final DateTime updated;

  Payment({
    required this.id,
    required this.brokerId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    this.createdBy,
    this.receipt,
    this.collectionId,
    required this.created,
    required this.updated,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? '',
      brokerId: json['broker_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paymentDate: DateTime.tryParse(json['payment_date'] ?? '') ?? DateTime.now(),
      notes: json['notes'],
      createdBy: json['created_by'],
      receipt: json['receipt'] is String && (json['receipt'] as String).isNotEmpty
          ? json['receipt']
          : null,
      collectionId: json['collectionId'],
      created: DateTime.tryParse(json['created'] ?? '') ?? DateTime.now(),      
      updated: DateTime.tryParse(json['updated'] ?? '') ?? DateTime.now(),      
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'broker_id': brokerId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'notes': notes,
      'created_by': createdBy ?? '',

    };
  }
}
