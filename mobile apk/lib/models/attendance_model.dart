class AttendanceRecord {
  final int id;
  final String date;
  final String? checkInTime;
  final String? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkInAccuracy;
  final String? checkInAddress;
  final String? checkInGoogleMapLink;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? checkOutAccuracy;
  final String? checkOutAddress;
  final String? checkOutGoogleMapLink;
  final String status;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInAccuracy,
    this.checkInAddress,
    this.checkInGoogleMapLink,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutAccuracy,
    this.checkOutAddress,
    this.checkOutGoogleMapLink,
    required this.status,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      checkInTime: json['check_in_time'],
      checkOutTime: json['check_out_time'],
      checkInLatitude: json['check_in_latitude'] != null
          ? (json['check_in_latitude'] as num).toDouble()
          : null,
      checkInLongitude: json['check_in_longitude'] != null
          ? (json['check_in_longitude'] as num).toDouble()
          : null,
      checkInAccuracy: json['check_in_accuracy'] != null
          ? (json['check_in_accuracy'] as num).toDouble()
          : null,
      checkInAddress: json['check_in_address'],
      checkInGoogleMapLink: json['check_in_google_map_link'] ?? json['google_map_link'],
      checkOutLatitude: json['check_out_latitude'] != null
          ? (json['check_out_latitude'] as num).toDouble()
          : null,
      checkOutLongitude: json['check_out_longitude'] != null
          ? (json['check_out_longitude'] as num).toDouble()
          : null,
      checkOutAccuracy: json['check_out_accuracy'] != null
          ? (json['check_out_accuracy'] as num).toDouble()
          : null,
      checkOutAddress: json['check_out_address'],
      checkOutGoogleMapLink: json['check_out_google_map_link'],
      status: json['status'] ?? 'PRESENT',
      notes: json['notes'],
    );
  }
}

class DailyTargetProgress {
  final int id;
  final String date;
  final double targetCashAmount;
  final double achievedCashAmount;
  final double cashCompletionPercentage;
  final int targetDonationsCount;
  final int achievedDonationsCount;
  final double targetProductUnits;
  final double achievedProductUnits;
  final bool isCashTargetMet;
  final String? notes;

  DailyTargetProgress({
    required this.id,
    required this.date,
    required this.targetCashAmount,
    required this.achievedCashAmount,
    required this.cashCompletionPercentage,
    required this.targetDonationsCount,
    required this.achievedDonationsCount,
    required this.targetProductUnits,
    required this.achievedProductUnits,
    required this.isCashTargetMet,
    this.notes,
  });

  factory DailyTargetProgress.fromJson(Map<String, dynamic> json) {
    return DailyTargetProgress(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      targetCashAmount: (num.tryParse(json['target_cash_amount']?.toString() ?? '0') ?? 0).toDouble(),
      achievedCashAmount: (num.tryParse(json['achieved_cash_amount']?.toString() ?? '0') ?? 0).toDouble(),
      cashCompletionPercentage: (num.tryParse(json['cash_completion_percentage']?.toString() ?? '0') ?? 0).toDouble(),
      targetDonationsCount: json['target_donations_count'] ?? 0,
      achievedDonationsCount: json['achieved_donations_count'] ?? 0,
      targetProductUnits: (num.tryParse(json['target_product_units']?.toString() ?? '0') ?? 0).toDouble(),
      achievedProductUnits: (num.tryParse(json['achieved_product_units']?.toString() ?? '0') ?? 0).toDouble(),
      isCashTargetMet: json['is_cash_target_met'] ?? false,
      notes: json['notes'],
    );
  }
}
