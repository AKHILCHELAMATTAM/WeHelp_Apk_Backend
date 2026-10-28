class CallLogModel {
  final int? id;
  final int? agentId;
  final String agentUsername;
  final String agentName;
  final String contactName;
  final String phoneNumber;
  final String callType;
  final String callTypeDisplay;
  final String status;
  final String statusDisplay;
  final int callDurationSeconds;
  final String formattedDuration;
  final double pledgedAmount;
  final String notes;
  final DateTime? followUpDate;
  final String leadCategory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CallLogModel({
    this.id,
    this.agentId,
    required this.agentUsername,
    required this.agentName,
    required this.contactName,
    required this.phoneNumber,
    required this.callType,
    required this.callTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.callDurationSeconds,
    required this.formattedDuration,
    required this.pledgedAmount,
    required this.notes,
    this.followUpDate,
    required this.leadCategory,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPledged => status == 'DONATION_PLEDGED' && pledgedAmount > 0;
  bool get isConnected => status == 'CONNECTED' || status == 'INTERESTED' || isPledged;
  bool get isCallback => status == 'CALLBACK_REQUESTED';

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    return CallLogModel(
      id: json['id'],
      agentId: json['agent_id'],
      agentUsername: json['agent_username'] ?? '',
      agentName: json['agent_name'] ?? (json['agent_username'] ?? 'Staff'),
      contactName: json['contact_name'] ?? 'Unknown Contact',
      phoneNumber: json['phone_number'] ?? '',
      callType: json['call_type'] ?? 'OUTGOING',
      callTypeDisplay: json['call_type_display'] ?? (json['call_type'] == 'INCOMING' ? 'Incoming' : 'Outgoing'),
      status: json['status'] ?? 'CONNECTED',
      statusDisplay: json['status_display'] ?? (json['status'] ?? 'Connected'),
      callDurationSeconds: json['call_duration_seconds'] ?? 0,
      formattedDuration: json['formatted_duration'] ?? _formatSeconds(json['call_duration_seconds'] ?? 0),
      pledgedAmount: (json['pledged_amount'] != null)
          ? double.tryParse(json['pledged_amount'].toString()) ?? 0.0
          : 0.0,
      notes: json['notes'] ?? '',
      followUpDate: json['follow_up_date'] != null
          ? DateTime.tryParse(json['follow_up_date'].toString())
          : null,
      leadCategory: json['lead_category'] ?? 'DONOR',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contact_name': contactName,
      'phone_number': phoneNumber,
      'call_type': callType,
      'status': status,
      'call_duration_seconds': callDurationSeconds,
      'pledged_amount': pledgedAmount.toStringAsFixed(2),
      'notes': notes,
      'follow_up_date': followUpDate?.toIso8601String(),
      'lead_category': leadCategory,
    };
  }

  static String _formatSeconds(int sec) {
    if (sec <= 0) return '0s';
    final m = sec ~/ 60;
    final s = sec % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}

class TelemarketingLeadModel {
  final int id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? city;
  final String category;
  final String categoryDisplay;
  final String status;
  final String statusDisplay;
  final String? assignedAgentName;
  final int totalCallsCount;
  final DateTime? lastCalledAt;
  final String notes;

  TelemarketingLeadModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.city,
    required this.category,
    required this.categoryDisplay,
    required this.status,
    required this.statusDisplay,
    this.assignedAgentName,
    required this.totalCallsCount,
    this.lastCalledAt,
    required this.notes,
  });

  factory TelemarketingLeadModel.fromJson(Map<String, dynamic> json) {
    return TelemarketingLeadModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      city: json['city'],
      category: json['category'] ?? 'DONOR',
      categoryDisplay: json['category_display'] ?? (json['category'] ?? 'Donor'),
      status: json['status'] ?? 'NEW',
      statusDisplay: json['status_display'] ?? (json['status'] ?? 'New'),
      assignedAgentName: json['assigned_agent_name'],
      totalCallsCount: json['total_calls_count'] ?? 0,
      lastCalledAt: json['last_called_at'] != null
          ? DateTime.tryParse(json['last_called_at'].toString())
          : null,
      notes: json['notes'] ?? '',
    );
  }
}

class CallSummaryModel {
  final int todayCallsCount;
  final int todayConnectedCount;
  final double todayPledgedAmount;
  final int totalCallsCount;
  final double totalPledgedAmount;

  CallSummaryModel({
    required this.todayCallsCount,
    required this.todayConnectedCount,
    required this.todayPledgedAmount,
    required this.totalCallsCount,
    required this.totalPledgedAmount,
  });

  factory CallSummaryModel.fromJson(Map<String, dynamic> json) {
    return CallSummaryModel(
      todayCallsCount: json['today_calls_count'] ?? 0,
      todayConnectedCount: json['today_connected_count'] ?? 0,
      todayPledgedAmount: (json['today_pledged_amount'] != null)
          ? double.tryParse(json['today_pledged_amount'].toString()) ?? 0.0
          : 0.0,
      totalCallsCount: json['total_calls_count'] ?? 0,
      totalPledgedAmount: (json['total_pledged_amount'] != null)
          ? double.tryParse(json['total_pledged_amount'].toString()) ?? 0.0
          : 0.0,
    );
  }
}
