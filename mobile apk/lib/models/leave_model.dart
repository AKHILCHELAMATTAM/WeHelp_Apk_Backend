class LeaveRequestModel {
  final int id;
  final String requestType; // LEAVE or WEEK_OFF
  final String startDate;
  final String endDate;
  final int totalDays;
  final String reason;
  final String status; // PENDING, APPROVED, REJECTED
  final String? adminRemarks;
  final String? reviewedByName;
  final String? reviewedAt;
  final String createdAt;
  final String? updatedAt;

  LeaveRequestModel({
    required this.id,
    required this.requestType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    this.adminRemarks,
    this.reviewedByName,
    this.reviewedAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  String get displayType =>
      requestType.toUpperCase() == 'WEEK_OFF' ? 'Weekly Off' : 'Leave Request';

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] ?? 0,
      requestType: json['request_type'] ?? 'LEAVE',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      totalDays: json['total_days'] ?? 1,
      reason: json['reason'] ?? '',
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      adminRemarks: json['admin_remarks'] ?? json['admin_comment'],
      reviewedByName: json['reviewed_by_name'],
      reviewedAt: json['reviewed_at'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
    );
  }
}
