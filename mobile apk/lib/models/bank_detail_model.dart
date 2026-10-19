class BankDetailModel {
  final int? id;
  final String accountHolderName;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String upiId;
  final String? branchName;
  final bool isActive;

  BankDetailModel({
    this.id,
    required this.accountHolderName,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    required this.upiId,
    this.branchName,
    required this.isActive,
  });

  bool get hasAccountDetails =>
      accountNumber != null && accountNumber!.trim().isNotEmpty;

  factory BankDetailModel.fromJson(Map<String, dynamic> json) {
    return BankDetailModel(
      id: json['id'],
      accountHolderName: json['account_holder_name'] ?? 'WeHelp Foundation',
      bankName: json['bank_name'],
      accountNumber: json['account_number'],
      ifscCode: json['ifsc_code'],
      upiId: json['upi_id'] ?? 'wehelp.donations@upi',
      branchName: json['branch_name'],
      isActive: json['is_active'] ?? true,
    );
  }
}
