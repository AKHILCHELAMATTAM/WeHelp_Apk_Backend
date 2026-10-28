import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_apk/models/bank_detail_model.dart';
import 'package:mobile_apk/models/call_log_model.dart';
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

  group('CallLogModel Tests', () {
    test('Call log model parses correctly and evaluates pledge helpers', () {
      final json = {
        'id': 1,
        'agent_id': 5,
        'agent_username': 'agent_rahul',
        'agent_name': 'Rahul Sharma',
        'contact_name': 'Dr. Sunita Sharma',
        'phone_number': '+919446054321',
        'call_type': 'OUTGOING',
        'call_type_display': 'Outgoing Call',
        'status': 'DONATION_PLEDGED',
        'status_display': 'Donation Pledged',
        'call_duration_seconds': 195,
        'formatted_duration': '3m 15s',
        'pledged_amount': '5000.00',
        'notes': 'Doctor pledged 5000 for student kits',
        'lead_category': 'SPONSOR',
      };

      final model = CallLogModel.fromJson(json);
      expect(model.contactName, 'Dr. Sunita Sharma');
      expect(model.phoneNumber, '+919446054321');
      expect(model.isPledged, true);
      expect(model.isConnected, true);
      expect(model.isCallback, false);
      expect(model.pledgedAmount, 5000.0);
      expect(model.formattedDuration, '3m 15s');
    });

    test('Telemarketing lead model parses correctly', () {
      final json = {
        'id': 2,
        'name': 'Rajesh Menon',
        'phone_number': '+919847012345',
        'city': 'Kochi',
        'category': 'DONOR',
        'category_display': 'Individual Donor',
        'status': 'NEW',
        'status_display': 'New Lead',
        'total_calls_count': 0,
        'notes': 'Interested in education sponsorship',
      };

      final lead = TelemarketingLeadModel.fromJson(json);
      expect(lead.name, 'Rajesh Menon');
      expect(lead.phoneNumber, '+919847012345');
      expect(lead.city, 'Kochi');
      expect(lead.status, 'NEW');
    });

    test('Call summary model parses correctly', () {
      final json = {
        'today_calls_count': 12,
        'today_connected_count': 8,
        'today_pledged_amount': 7500.0,
        'total_calls_count': 45,
        'total_pledged_amount': 25000.0,
      };

      final summary = CallSummaryModel.fromJson(json);
      expect(summary.todayCallsCount, 12);
      expect(summary.todayConnectedCount, 8);
      expect(summary.todayPledgedAmount, 7500.0);
    });
  });
}
