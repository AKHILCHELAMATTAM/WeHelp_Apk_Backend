import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/leave_model.dart';

class SupplyRequestsScreen extends StatefulWidget {
  const SupplyRequestsScreen({super.key});

  @override
  State<SupplyRequestsScreen> createState() => _SupplyRequestsScreenState();
}

class _SupplyRequestsScreenState extends State<SupplyRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<LeaveRequestModel> _requestsList = [];

  // Supply Request form state
  final _supplyFormKey = GlobalKey<FormState>();
  String _selectedSupplyItem = 'Grocery Collection Sacks & Bags (Pack of 50)';
  String _supplyUrgency = 'Normal';
  final _supplyQuantityController = TextEditingController(text: '1');
  final _supplyDeliveryLocationController = TextEditingController();
  final _supplyReasonController = TextEditingController();

  final List<String> _supplyItems = [
    'Grocery Collection Sacks & Bags (Pack of 50)',
    'Physical Numbered Receipt Books (2 Books)',
    'Official WeHelp QR Standee & Promotional Banners',
    'Field Agent ID Badge & Lanyard Replacement',
    'Tamper-evident Cash Collection Donation Box',
    'Ration Relief Distribution Packets',
    'Field First-Aid & Emergency Supplies Kit',
  ];

  // Leave / Week-Off Form state
  final _leaveFormKey = GlobalKey<FormState>();
  String _selectedLeaveType = 'LEAVE'; // LEAVE or WEEK_OFF
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  final _leaveReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchRequests();
  }

  void _handleTabChange() {
    // Automatic status update: refresh when agent taps or navigates to the Status tab
    if (_tabController.index == 2 && !_tabController.indexIsChanging) {
      _fetchRequests();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _supplyQuantityController.dispose();
    _supplyDeliveryLocationController.dispose();
    _supplyReasonController.dispose();
    _leaveReasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiClient.get(ApiConstants.leaveRequests);

    if (!mounted) return;

    if (res.isSuccess && res.data != null && res.data is List) {
      setState(() {
        _requestsList = (res.data as List)
            .map((item) => LeaveRequestModel.fromJson(item))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.errorMessage ?? 'Unable to load requests. Please check internet connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitSupplyRequest() async {
    if (_isSubmitting) return; // Prevent duplicate submissions
    if (!_supplyFormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final reasonText = 'SUPPLY REQUEST: $_selectedSupplyItem (Qty: ${_supplyQuantityController.text.trim()}, Priority: $_supplyUrgency)\n'
        'Destination: ${_supplyDeliveryLocationController.text.trim()}\n'
        'Details: ${_supplyReasonController.text.trim()}';

    final payload = {
      'request_type': 'LEAVE',
      'start_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'end_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'reason': reasonText,
    };

    final res = await ApiClient.post(ApiConstants.leaveRequests, body: payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('✓ Supply request submitted to Admin successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _supplyReasonController.clear();
      _supplyDeliveryLocationController.clear();
      _tabController.animateTo(2); // Jump to status tab
      _fetchRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Failed to submit supply request'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (_isSubmitting) return; // Prevent duplicate submissions caused by multiple taps

    if (!_leaveFormKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('End date cannot be before start date'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'request_type': _selectedLeaveType,
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      'reason': _leaveReasonController.text.trim(),
    };

    final res = await ApiClient.post(ApiConstants.leaveRequests, body: payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.isSuccess) {
      final typeTitle = _selectedLeaveType == 'WEEK_OFF' ? 'Weekly Off' : 'Leave';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('✓ $typeTitle request submitted to Admin for review!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _leaveReasonController.clear();
      _tabController.animateTo(2); // Jump to status tab
      _fetchRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Failed to submit leave request'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestedDays = _endDate.difference(_startDate).inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _fetchRequests,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_rounded), text: 'SUPPLIES'),
            Tab(icon: Icon(Icons.event_note_rounded), text: 'LEAVE / OFF'),
            Tab(icon: Icon(Icons.history_rounded), text: 'STATUS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Supply Requests
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _supplyFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.local_shipping_rounded, color: Color(0xFF1D4ED8), size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Request collection bags, receipt books, QR banners, or inventory supplies from admin.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedSupplyItem,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Required Supply Material',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: _supplyItems.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(item, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSupplyItem = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _supplyQuantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon: Icon(Icons.format_list_numbered_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter qty' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _supplyUrgency,
                          decoration: const InputDecoration(
                            labelText: 'Urgency',
                            prefixIcon: Icon(Icons.speed_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'High', child: Text('High')),
                            DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _supplyUrgency = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _supplyDeliveryLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Field Point / Delivery Location',
                      hintText: 'e.g. Ward 4 Relief Camp, Main Office',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter delivery point' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _supplyReasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason / Purpose',
                      hintText: 'e.g. Current receipt book full, extra drive tomorrow',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter justification' : null,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitSupplyRequest,
                    icon: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(_isSubmitting ? 'SUBMITTING...' : 'SUBMIT SUPPLY REQUEST'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab 2: Leave & Weekly-Off Form
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _leaveFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: Color(0xFFD97706), size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Submit weekly off or leave requests. The administrator will review and update status.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Request Type Selector (Leave vs Weekly Off)
                  const Text(
                    'Request Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text('Leave (Casual/Sick)'),
                            ),
                          ),
                          selected: _selectedLeaveType == 'LEAVE',
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: _selectedLeaveType == 'LEAVE' ? Colors.white : AppTheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedLeaveType = 'LEAVE');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text('Weekly Off'),
                            ),
                          ),
                          selected: _selectedLeaveType == 'WEEK_OFF',
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: _selectedLeaveType == 'WEEK_OFF' ? Colors.white : AppTheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedLeaveType = 'WEEK_OFF');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date range picker cards
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Date', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('dd MMM yyyy').format(_startDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Date', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('dd MMM yyyy').format(_endDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total Days: $requestedDays ${requestedDays == 1 ? "day" : "days"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _leaveReasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Leave / Weekly Off *',
                      hintText: 'e.g. Scheduled weekly rest day, family emergency, medical visit',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a reason' : null,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitLeaveRequest,
                    icon: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(_isSubmitting ? 'SUBMITTING REQUEST...' : 'SUBMIT REQUEST TO ADMIN'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab 3: Request Status Tracker (Requirement #4)
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 54, color: AppTheme.error),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchRequests,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _requestsList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'No submitted requests yet.',
                                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Submit a leave, weekly off, or supply request above.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchRequests,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _requestsList.length,
                            itemBuilder: (ctx, index) {
                              final req = _requestsList[index];

                              // Visually distinct indicators (Requirement #4)
                              // Pending: yellow or amber
                              // Approved: green
                              // Rejected: red
                              Color badgeBg;
                              Color badgeFg;
                              IconData statusIcon;

                              if (req.isApproved) {
                                badgeBg = const Color(0xFFDEF7EC); // Soft emerald green
                                badgeFg = const Color(0xFF03543F);
                                statusIcon = Icons.check_circle_rounded;
                              } else if (req.isRejected) {
                                badgeBg = const Color(0xFFFDE8E8); // Soft red
                                badgeFg = const Color(0xFF9B1C1C);
                                statusIcon = Icons.cancel_rounded;
                              } else {
                                // Default Pending
                                badgeBg = const Color(0xFFFEF3C7); // Warm amber
                                badgeFg = const Color(0xFF92400E);
                                statusIcon = Icons.hourglass_top_rounded;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header: Request Type & Status Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                req.requestType == 'WEEK_OFF'
                                                    ? Icons.weekend_rounded
                                                    : Icons.event_busy_rounded,
                                                color: AppTheme.primary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                req.displayType,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: AppTheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: badgeBg,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(statusIcon, size: 14, color: badgeFg),
                                                const SizedBox(width: 4),
                                                Text(
                                                  req.status,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: badgeFg,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      const SizedBox(height: 10),

                                      // Requested Date or Date Range
                                      Row(
                                        children: [
                                          const Icon(Icons.date_range_rounded, size: 15, color: Color(0xFF64748B)),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${_formatDate(req.startDate)} to ${_formatDate(req.endDate)} (${req.totalDays} ${req.totalDays == 1 ? "day" : "days"})',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Reason
                                      Text(
                                        req.reason,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3),
                                      ),

                                      // Submission timestamp
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Submitted on: ${_formatDateTime(req.createdAt)}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),

                                      // Admin Remarks / Rejection reason banner
                                      if (req.adminRemarks != null && req.adminRemarks!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: req.isApproved
                                                ? const Color(0xFFF0FDF4)
                                                : req.isRejected
                                                    ? const Color(0xFFFEF2F2)
                                                    : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: req.isApproved
                                                  ? const Color(0xFFBBF7D0)
                                                  : req.isRejected
                                                      ? const Color(0xFFFECACA)
                                                      : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    req.isApproved
                                                        ? Icons.verified_user_rounded
                                                        : req.isRejected
                                                            ? Icons.feedback_rounded
                                                            : Icons.comment_rounded,
                                                    size: 15,
                                                    color: req.isApproved
                                                        ? const Color(0xFF16A34A)
                                                        : req.isRejected
                                                            ? const Color(0xFFDC2626)
                                                            : const Color(0xFF475569),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    req.isRejected ? 'Admin Rejection Reason:' : 'Admin Remark:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: req.isApproved
                                                          ? const Color(0xFF166534)
                                                          : req.isRejected
                                                              ? const Color(0xFF991B1B)
                                                              : const Color(0xFF334155),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                req.adminRemarks!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              if (req.reviewedAt != null && req.reviewedAt!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Decision recorded: ${_formatDateTime(req.reviewedAt)}${req.reviewedByName != null ? " by ${req.reviewedByName}" : ""}',
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ],
      ),
    );
  }
}
