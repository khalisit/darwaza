class ActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String actionType; // create, update, delete, payment, login
  final String entityType; // broker, transaction, payment
  final String? entityId;
  final String description;
  final DateTime created;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.actionType,
    required this.entityType,
    this.entityId,
    required this.description,
    required this.created,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      actionType: json['action_type'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'],
      description: json['description'] ?? '',
      created: DateTime.tryParse(json['created'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'action_type': actionType,
      'entity_type': entityType,
      'entity_id': entityId ?? '',
      'description': description,
    };
  }

  IconLabel get actionIcon {
    switch (actionType) {
      case 'create':
        return const IconLabel('زیادکردن', 0xFF43A047);
      case 'update':
        return const IconLabel('نوێکردنەوە', 0xFF3B82F6);
      case 'delete':
        return const IconLabel('سڕینەوە', 0xFFE53935);
      case 'payment':
        return const IconLabel('پارەدان', 0xFFFFA726);
      case 'login':
        return const IconLabel('چوونەژوورەوە', 0xFF7C3AED);
      default:
        return const IconLabel('نەزانراو', 0xFF6B7280);
    }
  }
}

class IconLabel {
  final String label;
  final int colorValue;
  const IconLabel(this.label, this.colorValue);
}
