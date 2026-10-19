class BankDetailModel {
  final int? id;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String accountType;
  final String upiId;
  final String? branchName;
  final bool isActive;

  BankDetailModel({
    this.id,
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountType,
    required this.upiId,
    this.branchName,
    required this.isActive,
  });

  bool get hasAccountDetails => accountNumber.trim().isNotEmpty;

  factory BankDetailModel.fromJson(Map<String, dynamic> json) {
    return BankDetailModel(
      id: json['id'],
      accountHolderName: json['account_holder_name'] ?? 'WeHelp Foundation',
      bankName: json['bank_name'] ?? 'Bank of Baroda',
      accountNumber: (json['account_number'] != null && json['account_number'].toString().trim().isNotEmpty)
          ? json['account_number'].toString()
          : '84278100000006',
      ifscCode: json['ifsc_code'] ?? 'BARB0VJIDUK',
      accountType: json['account_type'] ?? 'Current Account',
      upiId: json['upi_id'] ?? 'wehelp.donations@upi',
      branchName: json['branch_name'] ?? 'Main Branch',
      isActive: json['is_active'] ?? true,
    );
  }
}
