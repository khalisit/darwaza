class Broker {
  final String id;
  final String name;
  final String phone;
  final String? companyName;
  final String? imageUrl;
  final String? createdBy;
  final DateTime created;
  final DateTime updated;

  Broker({
    required this.id,
    required this.name,
    required this.phone,
    this.companyName,
    this.imageUrl,
    this.createdBy,
    required this.created,
    required this.updated,
  });

  factory Broker.fromJson(Map<String, dynamic> json) {
    return Broker(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      companyName: json['company_name'],
      imageUrl: json['image_url'],
      createdBy: json['created_by'],
      created: DateTime.tryParse(json['created'] ?? '') ?? DateTime.now(),
      updated: DateTime.tryParse(json['updated'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'company_name': companyName,
      'image_url': imageUrl,
    };
  }

  double totalDebt = 0;
  double totalPaid = 0;
  double get balance => totalDebt - totalPaid;
}
