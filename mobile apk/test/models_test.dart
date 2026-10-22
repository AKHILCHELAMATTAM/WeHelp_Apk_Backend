import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_apk/models/bank_detail_model.dart';
import 'package:mobile_apk/models/leave_model.dart';

void main() {
  group('BankDetailModel Tests', () {
    test('Official default bank account fallback', () {
      final json = {
        'account_holder_name': 'WE HELP CHARITABLE SOCIETY AND EDUCATION',
        'bank_name': null,
        'account_number': null,
        'ifsc_code': null,
        'upi_id': '3113201002320@cnrb',
      };
      final model = BankDetailModel.fromJson(json);
      expect(model.accountHolderName, 'WE HELP CHARITABLE SOCIETY AND EDUCATION');
      expect(model.hasAccountDetails, true);
      expect(model.accountNumber, '3113201002320');
      expect(model.bankName, 'Canara Bank');
      expect(model.ifscCode, 'CNRB0003113');
      expect(model.accountType, 'Current Account');
    });

    test('Valid bank account details parsing', () {
      final json = {
        'id': 1,
        'account_holder_name': 'WeHelp Foundation Trust',
        'bank_name': 'State Bank of India',
        'account_number': '39912345678',
        'ifsc_code': 'SBIN0001234',
        'upi_id': 'wehelp@sbi',
        'branch_name': 'City Branch',
        'is_active': true,
      };
      final model = BankDetailModel.fromJson(json);
      expect(model.accountHolderName, 'WeHelp Foundation Trust');
      expect(model.bankName, 'State Bank of India');
      expect(model.accountNumber, '39912345678');
      expect(model.ifscCode, 'SBIN0001234');
      expect(model.hasAccountDetails, true);
    });
  });

  group('LeaveRequestModel Tests', () {
    test('Leave request model parses correctly and reflects status helpers', () {
      final pendingJson = {
        'id': 10,
        'request_type': 'LEAVE',
        'start_date': '2026-10-20',
        'end_date': '2026-10-22',
        'total_days': 3,
        'reason': 'Medical checkup',
        'status': 'PENDING',
        'created_at': '2026-10-19T08:00:00Z',
      };
      final pendingModel = LeaveRequestModel.fromJson(pendingJson);
      expect(pendingModel.isPending, true);
      expect(pendingModel.isApproved, false);
      expect(pendingModel.isRejected, false);
      expect(pendingModel.displayType, 'Leave Request');
      expect(pendingModel.totalDays, 3);

      final approvedJson = {
        'id': 11,
        'request_type': 'WEEK_OFF',
        'start_date': '2026-10-25',
        'end_date': '2026-10-25',
        'total_days': 1,
        'reason': 'Scheduled rest day',
        'status': 'APPROVED',
        'admin_remarks': 'Approved by Duty Roster Manager',
        'reviewed_by_name': 'Admin Rahul',
        'reviewed_at': '2026-10-19T09:30:00Z',
        'created_at': '2026-10-19T08:00:00Z',
      };
      final approvedModel = LeaveRequestModel.fromJson(approvedJson);
      expect(approvedModel.isApproved, true);
      expect(approvedModel.isPending, false);
      expect(approvedModel.displayType, 'Weekly Off');
      expect(approvedModel.adminRemarks, 'Approved by Duty Roster Manager');
      expect(approvedModel.reviewedByName, 'Admin Rahul');

      final rejectedJson = {
        'id': 12,
        'request_type': 'LEAVE',
        'start_date': '2026-10-21',
        'end_date': '2026-10-23',
        'total_days': 3,
        'reason': 'Vacation',
        'status': 'REJECTED',
        'admin_remarks': 'High volume donation drive on selected dates.',
        'created_at': '2026-10-19T08:00:00Z',
      };
      final rejectedModel = LeaveRequestModel.fromJson(rejectedJson);
      expect(rejectedModel.isRejected, true);
      expect(rejectedModel.adminRemarks, 'High volume donation drive on selected dates.');
    });
  });
}
