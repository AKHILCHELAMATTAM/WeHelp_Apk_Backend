import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bank_detail_model.dart';
import '../../models/donation_model.dart';

class DonationCollectionScreen extends StatefulWidget {
  const DonationCollectionScreen({super.key});

  @override
  State<DonationCollectionScreen> createState() => _DonationCollectionScreenState();
}

class _DonationCollectionScreenState extends State<DonationCollectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _cashFormKey = GlobalKey<FormState>();

  final _donorNameController = TextEditingController();
  final _donorPhoneController = TextEditingController();
  final _donorEmailController = TextEditingController();
  final _amountController = TextEditingController(text: '500');
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingBank = false;
  BankDetailModel? _bankDetails;

  final List<double> _quickAmounts = [100, 250, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBankDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _donorNameController.dispose();
    _donorPhoneController.dispose();
    _donorEmailController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchBankDetails() async {
    setState(() => _isLoadingBank = true);
    final res = await ApiClient.get(ApiConstants.bankDetails);
    if (mounted) {
      if (res.isSuccess && res.data != null) {
        setState(() {
          _bankDetails = BankDetailModel.fromJson(res.data);
          _isLoadingBank = false;
        });
      } else {
        setState(() => _isLoadingBank = false);
      }
    }
  }

  String _buildUpiQrString() {
    final amount = double.tryParse(_amountController.text) ?? 500.0;
    final vpa = _bankDetails?.upiId.isNotEmpty == true
        ? _bankDetails!.upiId
        : 'wehelp.donations@upi';
    final orgName = Uri.encodeComponent(
      _bankDetails?.accountHolderName.isNotEmpty == true
          ? _bankDetails!.accountHolderName
          : 'WeHelp Foundation',
    );
    return 'upi://pay?pa=$vpa&pn=$orgName&am=${amount.toStringAsFixed(2)}&cu=INR&tn=Field%20Donation';
  }

  Future<void> _submitDonation({required String paymentMode}) async {
    if (!_cashFormKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() => _isSubmitting = true);

    // Get current GPS coordinates for donation audit trail
    final loc = await LocationService.getCurrentLocation();

    final payload = {
      'donor_name': _donorNameController.text.trim(),
      'donor_phone': _donorPhoneController.text.trim(),
      'donor_email': _donorEmailController.text.trim(),
      'amount': _amountController.text.trim(),
      'currency': 'INR',
      'payment_mode': paymentMode,
      'notes': _notesController.text.trim(),
      'latitude': loc?.latitude,
      'longitude': loc?.longitude,
      'address': loc?.address,
    };

    final res = await ApiClient.post(ApiConstants.cashDonation, body: payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.isSuccess && res.data != null) {
      final donationData = res.data['donation'];
      final donation = DonationRecord.fromJson(donationData);
      _showReceiptDialog(donation);
      _resetForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Failed to record donation'),
        ),
      );
    }
  }

  void _resetForm() {
    _donorNameController.clear();
    _donorPhoneController.clear();
    _donorEmailController.clear();
    _notesController.clear();
    setState(() {
      _amountController.text = '500';
    });
  }

  void _showReceiptDialog(DonationRecord donation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            SizedBox(width: 10),
            Text('Donation Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDEF7EC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Receipt #: ${donation.receiptNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF03543F), fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _receiptRow('Donor:', donation.donorName),
                  const SizedBox(height: 8),
                  _receiptRow('Amount:', '₹${donation.amount?.toStringAsFixed(2) ?? "0.00"}', isBold: true),
                  const SizedBox(height: 8),
                  _receiptRow('Payment Mode:', donation.paymentMode),
                  const SizedBox(height: 8),
                  _receiptRow('Date:', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final text = 'WeHelp Donation Receipt\nNumber: ${donation.receiptNumber}\nDonor: ${donation.donorName}\nAmount: ₹${donation.amount}\nThank you for your generous support!';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy SMS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppTheme.primary : AppTheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBankAccountDetailsCard() {
    if (_isLoadingBank) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          ),
        ),
      );
    }

    final hasAccount = _bankDetails?.hasAccountDetails == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Bank Transfer Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.secondary),
                      ),
                      Text(
                        'IMPS • NEFT • RTGS Bank Transfer',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            if (hasAccount) ...[
              _bankDetailRow(
                'Account Holder',
                _bankDetails!.accountHolderName,
              ),
              const SizedBox(height: 10),
              _bankDetailRow('Bank Name', _bankDetails!.bankName),
              const SizedBox(height: 10),
              // Clearly labeled Account Number with Copy Button
              _bankDetailRowWithCopy(
                'Account Number',
                _bankDetails!.accountNumber,
                copyLabel: 'Account number',
              ),
              const SizedBox(height: 10),
              _bankDetailRow('Account Type', _bankDetails!.accountType),
              const SizedBox(height: 10),
              _bankDetailRowWithCopy(
                'IFSC Code',
                _bankDetails!.ifscCode,
                copyLabel: 'IFSC Code',
              ),
              if (_bankDetails!.branchName != null && _bankDetails!.branchName!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _bankDetailRow('Branch', _bankDetails!.branchName!),
              ],
              const SizedBox(height: 10),
              _bankDetailRowWithCopy(
                'UPI ID / VPA',
                _bankDetails!.upiId,
                copyLabel: 'UPI ID',
              ),
            ] else ...[
              // Graceful fallback when details not yet supplied by admin
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Official bank account details will appear here once configured by the administrator.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bankDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondary),
          ),
        ),
      ],
    );
  }

  Widget _bankDetailRowWithCopy(String label, String value, {required String copyLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$copyLabel copied to clipboard!'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 13, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text(
                      'COPY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Donation'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_2_rounded), text: 'UPI / QR CODE'),
            Tab(icon: Icon(Icons.payments_rounded), text: 'CASH ENTRY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: QR Code Donation Collection + Bank Account Details
          RefreshIndicator(
            onRefresh: _fetchBankDetails,
            color: AppTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Amount selector
                  const Text(
                    'Select or Enter Donation Amount',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: _quickAmounts.map((amt) {
                      final isSelected = _amountController.text == amt.toStringAsFixed(0);
                      return ChoiceChip(
                        label: Text('₹${amt.toStringAsFixed(0)}'),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _amountController.text = amt.toStringAsFixed(0);
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Custom Donation Amount (₹)',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),

                  // QR Code Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        children: [
                          const Text(
                            'Scan with any UPI App',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Google Pay • PhonePe • Paytm • BHIM',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            ),
                            child: QrImageView(
                              data: _buildUpiQrString(),
                              version: QrVersions.auto,
                              size: 200.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Amount: ₹${_amountController.text}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_rounded, size: 16, color: AppTheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'A/C: ${_bankDetails?.accountNumber ?? "84278100000006"}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(
                                      text: _bankDetails?.accountNumber ?? "84278100000006",
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Bank Account Number copied!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bank Account Number & Details Section (Requirement #3)
                  _buildBankAccountDetailsCard(),
                  const SizedBox(height: 20),

                  // Donor Name & Phone for QR Confirmation
                  Form(
                    key: _cashFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _donorNameController,
                          decoration: const InputDecoration(
                            labelText: 'Donor Full Name',
                            hintText: 'e.g. Ramesh Kumar',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter donor name' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _donorPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Donor Mobile Number (Optional)',
                            hintText: '+91 9876543210',
                            prefixIcon: Icon(Icons.phone_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _submitDonation(paymentMode: 'QR_CODE'),
                    icon: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_rounded),
                    label: Text(_isSubmitting ? 'GENERATING RECEIPT...' : 'CONFIRM QR PAYMENT RECEIVED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab 2: Cash Donation Entry
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cash Collection Entry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter donor and cash details. A numbered digital receipt will be generated automatically.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _donorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Donor Name *',
                    hintText: 'Enter name of donor',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _donorPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91 9876543210',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _donorEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'donor@gmail.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cash Amount (₹) *',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Notes (Optional)',
                    hintText: 'e.g. Flood relief fund, temple donation box',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _submitDonation(paymentMode: 'CASH'),
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.receipt_long_rounded),
                  label: Text(_isSubmitting ? 'PROCESSING...' : 'SAVE CASH DONATION & ISSUE RECEIPT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
