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
      accountHolderName: json['account_holder_name'] ?? 'WE HELP CHARITABLE SOCIETY AND EDUCATION',
      bankName: json['bank_name'] ?? 'Canara Bank',
      accountNumber: (json['account_number'] != null && json['account_number'].toString().trim().isNotEmpty)
          ? json['account_number'].toString()
          : '3113201002320',
      ifscCode: json['ifsc_code'] ?? 'CNRB0003113',
      accountType: json['account_type'] ?? 'Current Account',
      upiId: json['upi_id'] ?? '3113201002320@cnrb',
      branchName: json['branch_name'] ?? 'Main Branch',
      isActive: json['is_active'] ?? true,
    );
  }
}
