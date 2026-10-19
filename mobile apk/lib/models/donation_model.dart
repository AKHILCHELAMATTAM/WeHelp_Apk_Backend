class DonationRecord {
  final int id;
  final String receiptNumber;
  final String donationType; // CASH or PRODUCT
  final String donorName;
  final String? donorPhone;
  final String? donorEmail;
  final String? donorAddress;
  final double? amount;
  final String currency;
  final String paymentMode;
  final String? paymentReference;
  final String paymentStatus;
  final String? productName;
  final String? productCategory;
  final double? quantity;
  final String? unit;
  final double? estimatedValue;
  final String status;
  final String? notes;
  final String createdAt;

  DonationRecord({
    required this.id,
    required this.receiptNumber,
    required this.donationType,
    required this.donorName,
    this.donorPhone,
    this.donorEmail,
    this.donorAddress,
    this.amount,
    this.currency = 'INR',
    this.paymentMode = 'CASH',
    this.paymentReference,
    this.paymentStatus = 'COMPLETED',
    this.productName,
    this.productCategory,
    this.quantity,
    this.unit,
    this.estimatedValue,
    this.status = 'RECEIVED',
    this.notes,
    required this.createdAt,
  });

  factory DonationRecord.fromJson(Map<String, dynamic> json) {
    return DonationRecord(
      id: json['id'] ?? 0,
      receiptNumber: json['receipt_number'] ?? '',
      donationType: json['donation_type'] ?? 'CASH',
      donorName: json['donor_name'] ?? 'Anonymous Donor',
      donorPhone: json['donor_phone'],
      donorEmail: json['donor_email'],
      donorAddress: json['donor_address'],
      amount: json['amount'] != null ? (num.tryParse(json['amount'].toString()) ?? 0).toDouble() : null,
      currency: json['currency'] ?? 'INR',
      paymentMode: json['payment_mode'] ?? 'CASH',
      paymentReference: json['payment_reference'],
      paymentStatus: json['payment_status'] ?? 'COMPLETED',
      productName: json['product_name'],
      productCategory: json['product_category'],
      quantity: json['quantity'] != null ? (num.tryParse(json['quantity'].toString()) ?? 0).toDouble() : null,
      unit: json['unit'],
      estimatedValue: json['estimated_value'] != null ? (num.tryParse(json['estimated_value'].toString()) ?? 0).toDouble() : null,
      status: json['status'] ?? 'RECEIVED',
      notes: json['notes'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class DonationsSummary {
  final double todayCashTotal;
  final int todayCashCount;
  final double todayProductTotalQuantity;
  final int todayProductCount;
  final int totalDonationsToday;

  DonationsSummary({
    required this.todayCashTotal,
    required this.todayCashCount,
    required this.todayProductTotalQuantity,
    required this.todayProductCount,
    required this.totalDonationsToday,
  });

  factory DonationsSummary.fromJson(Map<String, dynamic> json) {
    return DonationsSummary(
      todayCashTotal: (num.tryParse(json['today_cash_total']?.toString() ?? '0') ?? 0).toDouble(),
      todayCashCount: json['today_cash_count'] ?? 0,
      todayProductTotalQuantity: (num.tryParse(json['today_product_total_quantity']?.toString() ?? '0') ?? 0).toDouble(),
      todayProductCount: json['today_product_count'] ?? 0,
      totalDonationsToday: json['total_donations_today'] ?? 0,
    );
  }
}
