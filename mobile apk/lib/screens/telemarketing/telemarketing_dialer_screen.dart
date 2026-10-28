import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_log_model.dart';
import '../../models/user_model.dart';

class TelemarketingDialerScreen extends StatefulWidget {
  final String? initialPhoneNumber;
  final String? initialContactName;

  const TelemarketingDialerScreen({
    super.key,
    this.initialPhoneNumber,
    this.initialContactName,
  });

  @override
  State<TelemarketingDialerScreen> createState() => _TelemarketingDialerScreenState();
}

class _TelemarketingDialerScreenState extends State<TelemarketingDialerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  // Dialpad input controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();

  // Data state
  bool _isLoadingSummary = false;
  bool _isLoadingLeads = false;
  bool _isLoadingLogs = false;
  bool _isAutoLogging = false;

  CallSummaryModel? _summary;
  List<TelemarketingLeadModel> _leads = [];
  List<CallLogModel> _callLogs = [];
  UserModel? _currentAgent;

  // Filter state for Leads
  String _leadSearchQuery = '';
  String _selectedLeadCategory = 'ALL';

  // Filter state for Call Logs
  String _logFilterStatus = 'ALL';

  // Active call lifecycle tracking for 30s auto-completion
  DateTime? _callStartTime;
  String? _activeDialedPhone;
  String? _activeDialedName;
  bool _isAwaitingCallReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialPhoneNumber != null) {
      _phoneController.text = widget.initialPhoneNumber!;
    }
    if (widget.initialContactName != null) {
      _contactNameController.text = widget.initialContactName!;
    }
    _loadCurrentAgent();
    _loadAllData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _phoneController.dispose();
    _contactNameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the agent returns to the app from the phone dialer, auto-complete call details
    if (state == AppLifecycleState.resumed && _isAwaitingCallReturn) {
      _handleReturnedFromCall();
    }
  }

  Future<void> _loadCurrentAgent() async {
    final user = await AuthService.getCachedUser();
    if (mounted && user != null) {
      setState(() {
        _currentAgent = user;
      });
    }
  }

  Future<void> _loadAllData() async {
    _fetchSummary();
    _fetchLeads();
    _fetchCallLogs();
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoadingSummary = true);
    final res = await ApiClient.get(ApiConstants.callSummary);
    if (mounted) {
      if (res.isSuccess && res.data != null) {
        setState(() {
          _summary = CallSummaryModel.fromJson(res.data);
          _isLoadingSummary = false;
        });
      } else {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoadingLeads = true);
    final res = await ApiClient.get(ApiConstants.telemarketingLeads);
    if (mounted) {
      if (res.isSuccess && res.data != null && res.data is List) {
        setState(() {
          _leads = (res.data as List)
              .map((item) => TelemarketingLeadModel.fromJson(item))
              .toList();
          _isLoadingLeads = false;
        });
      } else {
        setState(() => _isLoadingLeads = false);
      }
    }
  }

  Future<void> _fetchCallLogs() async {
    setState(() => _isLoadingLogs = true);
    final res = await ApiClient.get(ApiConstants.callLogs);
    if (mounted) {
      if (res.isSuccess && res.data != null && res.data is List) {
        setState(() {
          _callLogs = (res.data as List)
              .map((item) => CallLogModel.fromJson(item))
              .toList();
          _isLoadingLogs = false;
        });
      } else {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  // Dialpad helper
  void _onDigitPressed(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _phoneController.text += digit;
    });
  }

  void _onBackspacePressed() {
    HapticFeedback.lightImpact();
    final text = _phoneController.text;
    if (text.isNotEmpty) {
      setState(() {
        _phoneController.text = text.substring(0, text.length - 1);
      });
    }
  }

  void _onClearPressed() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phoneController.clear();
      _contactNameController.clear();
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _phoneController.text = data.text!.trim();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasted from clipboard'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  // ----------------------------------------------------
  // CALL INITIATION & AUTO-COMPLETION ENGINE
  // ----------------------------------------------------
  Future<void> _initiateCall(String phone, String name) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number to call.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Auto-resolve contact name if not provided
    String resolvedName = name.trim();
    if (resolvedName.isEmpty) {
      final matchedLead = _leads.where((l) {
        final leadNum = l.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
        return leadNum.contains(cleanPhone) || cleanPhone.contains(leadNum);
      }).firstOrNull;
      resolvedName = matchedLead != null ? matchedLead.name : 'Contact ($cleanPhone)';
    }

    // Set call tracking state before opening phone app
    setState(() {
      _activeDialedPhone = cleanPhone;
      _activeDialedName = resolvedName;
      _callStartTime = DateTime.now();
      _isAwaitingCallReturn = true;
    });

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer for $cleanPhone'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Launch dialer exception: $e');
    }
  }

  // Triggered when agent resumes back into the app after phone conversation
  void _handleReturnedFromCall() async {
    if (!_isAwaitingCallReturn || _activeDialedPhone == null || _callStartTime == null) return;
    _isAwaitingCallReturn = false;

    final elapsed = DateTime.now().difference(_callStartTime!).inSeconds;
    // Auto-complete duration: defaults to 30s as requested by user, or exact if longer
    final int finalDuration = (elapsed >= 5 && elapsed <= 50) ? 30 : (elapsed > 50 ? elapsed : 30);

    final phone = _activeDialedPhone!;
    final name = _activeDialedName ?? 'Contact ($phone)';
    _callStartTime = null;

    await _executeAutoLogCall(
      phoneNumber: phone,
      contactName: name,
      durationSeconds: finalDuration,
      isAutoTriggered: true,
    );
  }

  // Core API call to auto-record call details (duration 30s, contact number, agent ID) to backend
  Future<void> _executeAutoLogCall({
    required String phoneNumber,
    required String contactName,
    required int durationSeconds,
    bool isAutoTriggered = false,
  }) async {
    if (_isAutoLogging) return;
    setState(() => _isAutoLogging = true);

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final agentId = _currentAgent?.id;
    final agentName = _currentAgent?.fullName ?? 'Agent';

    final payload = {
      'contact_name': contactName.isNotEmpty ? contactName : 'Contact ($cleanPhone)',
      'phone_number': cleanPhone,
      'call_type': 'OUTGOING',
      'status': 'CONNECTED',
      'call_duration_seconds': durationSeconds,
      'pledged_amount': '0.00',
      'notes': 'Auto-completed call log (Duration: ${durationSeconds}s | Agent ID: #${agentId ?? ""} $agentName)',
      'lead_category': 'DONOR',
    };

    final res = await ApiClient.post(ApiConstants.callLogs, body: payload);

    if (!mounted) return;
    setState(() => _isAutoLogging = false);

    if (res.isSuccess && res.data != null) {
      final savedLogJson = res.data is Map ? (res.data['call_log'] ?? res.data) : null;
      CallLogModel? savedLog;
      if (savedLogJson != null && savedLogJson is Map<String, dynamic>) {
        savedLog = CallLogModel.fromJson(savedLogJson);
      }

      // Refresh KPIs and list data
      _loadAllData();

      // Show prominent auto-complete confirmation bottom sheet
      _showAutoCompleteConfirmationSheet(
        callLog: savedLog,
        phoneNumber: cleanPhone,
        contactName: contactName.isNotEmpty ? contactName : 'Contact ($cleanPhone)',
        durationSeconds: durationSeconds,
        isAutoTriggered: isAutoTriggered,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Failed to auto-log call.'),
        ),
      );
    }
  }

  // Manual one-tap action: "Auto-Log 30s Call" on Dialpad
  void _onDirectAutoLogPressed() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number to auto-log.'),
          backgroundColor: AppTheme.accent,
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    String contactName = _contactNameController.text.trim();
    if (contactName.isEmpty) {
      final matchedLead = _leads.where((l) {
        final leadNum = l.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
        return leadNum.contains(cleanPhone) || cleanPhone.contains(leadNum);
      }).firstOrNull;
      contactName = matchedLead != null ? matchedLead.name : 'Contact ($cleanPhone)';
    }

    _executeAutoLogCall(
      phoneNumber: cleanPhone,
      contactName: contactName,
      durationSeconds: 30, // 30s duration auto-completed!
      isAutoTriggered: false,
    );
  }

  // Auto-Complete Confirmation Bottom Sheet
  void _showAutoCompleteConfirmationSheet({
    required CallLogModel? callLog,
    required String phoneNumber,
    required String contactName,
    required int durationSeconds,
    required bool isAutoTriggered,
  }) {
    final agentId = callLog?.agentId ?? _currentAgent?.id;
    final agentName = callLog?.agentName ?? _currentAgent?.fullName ?? 'Telemarketing Agent';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Success Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDEF7EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF03543F),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Call Details Auto-Completed',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDEF7EC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 6, color: Color(0xFF03543F)),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE IN ADMIN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF03543F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAutoTriggered
                            ? 'Auto-detected return from phone call (~30s duration recorded).'
                            : 'Auto-recorded call details with 30s duration to Admin Dashboard.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Card with Contact Number, Agent ID & Duration details
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _detailRow(
                    icon: Icons.phone_rounded,
                    label: 'Contact Number',
                    value: phoneNumber,
                    valueColor: const Color(0xFF0284C7),
                    isBold: true,
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow(
                    icon: Icons.person_rounded,
                    label: 'Contact Name',
                    value: contactName,
                    isBold: true,
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow(
                    icon: Icons.badge_rounded,
                    label: 'Agent ID',
                    value: 'Agent ID: #${agentId ?? "-"} ($agentName)',
                    valueColor: const Color(0xFF4338CA),
                    isBold: true,
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow(
                    icon: Icons.timer_rounded,
                    label: 'Call Duration',
                    value: '${durationSeconds}s (Auto-Completed)',
                    valueColor: const Color(0xFF059669),
                    isBold: true,
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _detailRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Outcome Status',
                    value: 'Connected / Spoke',
                    valueColor: const Color(0xFF059669),
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Open modal to add pledge or remarks to this call log
                      _showCallOutcomeSheet(
                        phoneNumber: phoneNumber,
                        contactName: contactName,
                        existingLogId: callLog?.id,
                        initialDuration: durationSeconds,
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primary),
                    label: const Text(
                      'Add Pledge / Notes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E9F6E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? AppTheme.secondary,
          ),
        ),
      ],
    );
  }

  // Modal Sheet for Logging / Updating Call Outcome
  void _showCallOutcomeSheet({
    required String phoneNumber,
    required String contactName,
    int? existingLogId,
    int initialDuration = 30,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CallOutcomeSheet(
        phoneNumber: phoneNumber,
        contactName: contactName,
        existingLogId: existingLogId,
        initialDuration: initialDuration,
        currentAgent: _currentAgent,
        onLogSaved: () {
          _fetchSummary();
          _fetchCallLogs();
          _fetchLeads();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemarketing & Dialer'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dialpad_rounded), text: 'DIALPAD'),
            Tab(icon: Icon(Icons.contacts_rounded), text: 'LEADS'),
            Tab(icon: Icon(Icons.history_rounded), text: 'CALL LOGS'),
          ],
        ),
      ),
      body: Column(
        children: [
          // KPI Metric Banner at Top
          _buildSummaryKpiBanner(),

          // Main Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDialpadTab(),
                _buildLeadsTab(),
                _buildCallLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpiBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: _isLoadingSummary
          ? const SizedBox(
              height: 28,
              child: Center(
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _kpiPill(
                  icon: Icons.phone_callback_rounded,
                  label: "Today's Calls",
                  value: '${_summary?.todayCallsCount ?? 0}',
                  color: const Color(0xFF0F5132),
                ),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                _kpiPill(
                  icon: Icons.check_circle_rounded,
                  label: 'Connected',
                  value: '${_summary?.todayConnectedCount ?? 0}',
                  color: const Color(0xFF2563EB),
                ),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                _kpiPill(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Pledged',
                  value: '₹${(_summary?.todayPledgedAmount ?? 0).toStringAsFixed(0)}',
                  color: const Color(0xFF059669),
                ),
              ],
            ),
    );
  }

  Widget _kpiPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // TAB 1: DIALPAD
  // ----------------------------------------------------
  Widget _buildDialpadTab() {
    final agentId = _currentAgent?.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Smart Auto-Complete Live Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart 30s Auto-Complete Active',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      Text(
                        'Calls auto-fill 30s duration, contact number, and Agent ID (#${agentId ?? "..."}) to Admin Dashboard.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Optional Contact Name Input
          TextField(
            controller: _contactNameController,
            decoration: InputDecoration(
              hintText: 'Contact Name (Optional)',
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primary),
              suffixIcon: _contactNameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _contactNameController.clear()),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Main Number Display Screen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.content_paste_rounded, color: AppTheme.primary),
                  tooltip: 'Paste Number',
                  onPressed: _pasteFromClipboard,
                ),
                Expanded(
                  child: Text(
                    _phoneController.text.isEmpty
                        ? 'Enter Phone Number'
                        : _phoneController.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _phoneController.text.isEmpty
                          ? const Color(0xFF94A3B8)
                          : AppTheme.secondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (_phoneController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, color: AppTheme.error),
                    tooltip: 'Backspace',
                    onPressed: _onBackspacePressed,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Keypad Grid
          _buildKeypad(),
          const SizedBox(height: 16),

          // Bottom Action Row
          Row(
            children: [
              // Clear All
              if (_phoneController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded, color: Colors.grey),
                  tooltip: 'Clear',
                  onPressed: _onClearPressed,
                ),

              // Large Call Now Button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final phone = _phoneController.text.trim();
                    final name = _contactNameController.text.trim();
                    _initiateCall(phone, name);
                  },
                  icon: const Icon(Icons.call_rounded, size: 22),
                  label: const Text(
                    'CALL NOW',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E9F6E), // Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Quick Auto-Log (30s) One-Tap Button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _isAutoLogging ? null : _onDirectAutoLogPressed,
                  icon: _isAutoLogging
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.flash_on_rounded, size: 20),
                  label: const Text(
                    'AUTO-LOG 30s',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), // Blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Manual Outcome Sheet icon button
              IconButton(
                icon: const Icon(Icons.post_add_rounded, color: AppTheme.primary, size: 26),
                tooltip: 'Log Call Outcome Manually',
                onPressed: () {
                  final phone = _phoneController.text.trim();
                  final name = _contactNameController.text.trim();
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter phone number to log call.')),
                    );
                    return;
                  }
                  _showCallOutcomeSheet(
                    phoneNumber: phone,
                    contactName: name.isNotEmpty ? name : 'Contact ($phone)',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    const keys = [
      ['1', ''],
      ['2', 'ABC'],
      ['3', 'DEF'],
      ['4', 'GHI'],
      ['5', 'JKL'],
      ['6', 'MNO'],
      ['7', 'PQRS'],
      ['8', 'TUV'],
      ['9', 'WXYZ'],
      ['*', ''],
      ['0', '+'],
      ['#', ''],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, idx) {
        final digit = keys[idx][0];
        final letters = keys[idx][1];
        return _dialpadButton(digit, letters);
      },
    );
  }

  Widget _dialpadButton(String digit, String letters) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        onLongPress: digit == '0' ? () => _onDigitPressed('+') : null,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppTheme.primary.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                digit,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: LEADS & CONTACTS
  // ----------------------------------------------------
  Widget _buildLeadsTab() {
    final filteredLeads = _leads.where((l) {
      final matchesSearch = _leadSearchQuery.isEmpty ||
          l.name.toLowerCase().contains(_leadSearchQuery.toLowerCase()) ||
          l.phoneNumber.contains(_leadSearchQuery) ||
          (l.city != null && l.city!.toLowerCase().contains(_leadSearchQuery.toLowerCase()));
      final matchesCategory =
          _selectedLeadCategory == 'ALL' || l.category == _selectedLeadCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchLeads,
      color: AppTheme.primary,
      child: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search leads by name, phone, city...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _leadSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _leadSearchQuery = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _leadSearchQuery = val.trim()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _leadCategoryChip('ALL', 'All Leads'),
                      _leadCategoryChip('DONOR', 'Donors'),
                      _leadCategoryChip('SPONSOR', 'Sponsors'),
                      _leadCategoryChip('CORPORATE', 'Corporate'),
                      _leadCategoryChip('VOLUNTEER', 'Volunteers'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Leads List
          Expanded(
            child: _isLoadingLeads
                ? const Center(child: CircularProgressIndicator())
                : filteredLeads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.contact_phone_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              'No telemarketing leads found.',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredLeads.length,
                        itemBuilder: (context, idx) {
                          final lead = filteredLeads[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                                    child: Text(
                                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'L',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                lead.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.secondary,
                                                ),
                                              ),
                                            ),
                                            _leadStatusBadge(lead.status, lead.statusDisplay),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          lead.phoneNumber +
                                              (lead.city != null && lead.city!.isNotEmpty
                                                  ? ' • ${lead.city}'
                                                  : ''),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (lead.notes.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            lead.notes,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Call Button with Auto-Complete on return
                                  ElevatedButton(
                                    onPressed: () {
                                      _initiateCall(lead.phoneNumber, lead.name);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0E9F6E),
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(10),
                                    ),
                                    child: const Icon(Icons.call_rounded, size: 20),
                                  ),
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

  Widget _leadCategoryChip(String categoryCode, String label) {
    final isSelected = _selectedLeadCategory == categoryCode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        onSelected: (val) {
          if (val) setState(() => _selectedLeadCategory = categoryCode);
        },
      ),
    );
  }

  Widget _leadStatusBadge(String status, String display) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (status == 'CONVERTED') {
      bg = const Color(0xFFDEF7EC);
      fg = const Color(0xFF03543F);
    } else if (status == 'CONTACTED') {
      bg = const Color(0xFFE1EFFE);
      fg = const Color(0xFF1E429F);
    } else if (status == 'LOST') {
      bg = const Color(0xFFFDE8E8);
      fg = const Color(0xFF9B1C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        display,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 3: CALL LOGS HISTORY
  // ----------------------------------------------------
  Widget _buildCallLogsTab() {
    final filteredLogs = _callLogs.where((log) {
      if (_logFilterStatus == 'ALL') return true;
      if (_logFilterStatus == 'PLEDGED') return log.isPledged;
      return log.status == _logFilterStatus;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchCallLogs,
      color: AppTheme.primary,
      child: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _logFilterChip('ALL', 'All Calls'),
                _logFilterChip('CONNECTED', 'Connected'),
                _logFilterChip('PLEDGED', 'Pledges'),
                _logFilterChip('CALLBACK', 'Callbacks'),
                _logFilterChip('BUSY', 'Busy'),
                _logFilterChip('NOT_INTERESTED', 'Declined'),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: _isLoadingLogs
                ? const Center(child: CircularProgressIndicator())
                : filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              'No call logs recorded yet.',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, idx) {
                          final log = filteredLogs[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: _getCallStatusColor(log.status).withValues(alpha: 0.15),
                                        child: Icon(
                                          log.callType == 'INCOMING'
                                              ? Icons.call_received_rounded
                                              : Icons.call_made_rounded,
                                          size: 18,
                                          color: _getCallStatusColor(log.status),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log.contactName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.secondary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Text(
                                                  log.phoneNumber,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF0284C7),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (log.agentId != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFEEF2FF),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'Agent ID: #${log.agentId}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF4338CA),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      _callStatusBadge(log.status, log.statusDisplay),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  const SizedBox(height: 8),

                                  // Details Row: Duration & Timestamp
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: log.callDurationSeconds >= 30
                                                  ? const Color(0xFFDEF7EC)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.timer_outlined,
                                                  size: 13,
                                                  color: log.callDurationSeconds >= 30
                                                      ? const Color(0xFF03543F)
                                                      : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  log.formattedDuration,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: log.callDurationSeconds >= 30
                                                        ? const Color(0xFF03543F)
                                                        : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (log.pledgedAmount > 0) ...[
                                            const SizedBox(width: 10),
                                            const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFF059669)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Pledged: ₹${log.pledgedAmount.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        log.createdAt != null
                                            ? DateFormat('dd MMM, hh:mm a').format(log.createdAt!)
                                            : 'Just now',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),

                                  if (log.notes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Note: ${log.notes}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
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

  Widget _logFilterChip(String filterCode, String label) {
    final isSelected = _logFilterStatus == filterCode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        onSelected: (val) {
          if (val) setState(() => _logFilterStatus = filterCode);
        },
      ),
    );
  }

  Color _getCallStatusColor(String status) {
    switch (status) {
      case 'CONNECTED':
      case 'INTERESTED':
      case 'DONATION_PLEDGED':
        return const Color(0xFF059669);
      case 'CALLBACK_REQUESTED':
        return const Color(0xFFD97706);
      case 'BUSY':
      case 'NO_ANSWER':
      case 'SWITCHED_OFF':
        return const Color(0xFF6B7280);
      case 'NOT_INTERESTED':
      case 'WRONG_NUMBER':
        return const Color(0xFFDC2626);
      default:
        return AppTheme.primary;
    }
  }

  Widget _callStatusBadge(String status, String display) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (status == 'CONNECTED' || status == 'INTERESTED' || status == 'DONATION_PLEDGED') {
      bg = const Color(0xFFDEF7EC);
      fg = const Color(0xFF03543F);
    } else if (status == 'CALLBACK_REQUESTED') {
      bg = const Color(0xFFFEF08A);
      fg = const Color(0xFF854D0E);
    } else if (status == 'NOT_INTERESTED' || status == 'WRONG_NUMBER') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        display,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

// ----------------------------------------------------
// BOTTOM SHEET MODAL: LOG OR UPDATE CALL OUTCOME
// ----------------------------------------------------
class _CallOutcomeSheet extends StatefulWidget {
  final String phoneNumber;
  final String contactName;
  final int? existingLogId;
  final int initialDuration;
  final VoidCallback onLogSaved;
  final UserModel? currentAgent;

  const _CallOutcomeSheet({
    required this.phoneNumber,
    required this.contactName,
    this.existingLogId,
    this.initialDuration = 30,
    required this.onLogSaved,
    this.currentAgent,
  });

  @override
  State<_CallOutcomeSheet> createState() => _CallOutcomeSheetState();
}

class _CallOutcomeSheetState extends State<_CallOutcomeSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _pledgeController = TextEditingController();

  String _selectedStatus = 'CONNECTED';
  late int _selectedDuration; // seconds, defaults to 30s
  DateTime? _followUpDate;
  bool _isSaving = false;

  final List<Map<String, String>> _dispositions = [
    {'code': 'CONNECTED', 'label': 'Connected / Spoke'},
    {'code': 'INTERESTED', 'label': 'Interested'},
    {'code': 'DONATION_PLEDGED', 'label': 'Donation Pledged'},
    {'code': 'CALLBACK_REQUESTED', 'label': 'Call Back Later'},
    {'code': 'BUSY', 'label': 'Busy'},
    {'code': 'NO_ANSWER', 'label': 'No Answer / Ringing'},
    {'code': 'SWITCHED_OFF', 'label': 'Switched Off'},
    {'code': 'WRONG_NUMBER', 'label': 'Wrong Number'},
    {'code': 'NOT_INTERESTED', 'label': 'Not Interested'},
  ];

  final List<Map<String, dynamic>> _durations = [
    {'label': '30s', 'sec': 30},
    {'label': '1m', 'sec': 60},
    {'label': '2m', 'sec': 120},
    {'label': '3m', 'sec': 180},
    {'label': '5m', 'sec': 300},
    {'label': '10m', 'sec': 600},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contactName);
    _phoneController = TextEditingController(text: widget.phoneNumber);
    _selectedDuration = widget.initialDuration;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _pledgeController.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );
      if (time != null) {
        setState(() {
          _followUpDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _submitCallLog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = {
      'contact_name': _nameController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'call_type': 'OUTGOING',
      'status': _selectedStatus,
      'call_duration_seconds': _selectedDuration,
      'pledged_amount': _selectedStatus == 'DONATION_PLEDGED'
          ? (_pledgeController.text.trim().isNotEmpty ? _pledgeController.text.trim() : '0.00')
          : '0.00',
      'notes': _notesController.text.trim(),
      'follow_up_date': _followUpDate?.toIso8601String(),
      'lead_category': 'DONOR',
    };

    final ApiResponse<dynamic> res;
    if (widget.existingLogId != null) {
      // Update existing auto-completed call log
      res = await ApiClient.patch('${ApiConstants.callLogs}${widget.existingLogId}/', body: payload);
    } else {
      // Create new call log
      res = await ApiClient.post(ApiConstants.callLogs, body: payload);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res.isSuccess) {
      Navigator.pop(context);
      widget.onLogSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0E9F6E),
          content: Text('Call details updated and synced to Admin Dashboard!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Failed to save call log.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentId = widget.currentAgent?.id;
    final agentName = widget.currentAgent?.fullName ?? 'Agent';

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title and Agent Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingLogId != null ? 'Update Call Details' : 'Record Call Outcome',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                        ),
                      ),
                      if (agentId != null)
                        Text(
                          'Agent ID: #$agentId ($agentName)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Contact Name & Phone
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Contact / Donor Name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter contact name' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 16),

              // Call Outcome / Disposition
              const Text(
                'Call Outcome',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dispositions.map((d) {
                  final isSelected = _selectedStatus == d['code'];
                  return ChoiceChip(
                    label: Text(d['label']!),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedStatus = d['code']!);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // If Donation Pledged -> Amount field
              if (_selectedStatus == 'DONATION_PLEDGED') ...[
                TextFormField(
                  controller: _pledgeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pledged Donation Amount (₹)',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.currency_rupee_rounded, color: Color(0xFF059669)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter pledged amount';
                    }
                    final num = double.tryParse(val);
                    if (num == null || num <= 0) {
                      return 'Please enter a valid amount greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // If Callback Requested -> Date/Time Picker
              if (_selectedStatus == 'CALLBACK_REQUESTED') ...[
                OutlinedButton.icon(
                  onPressed: _pickFollowUpDate,
                  icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
                  label: Text(
                    _followUpDate == null
                        ? 'Select Follow-up Callback Date & Time'
                        : 'Callback: ${DateFormat('dd MMM yyyy, hh:mm a').format(_followUpDate!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Call Duration Selector (30s default)
              const Text(
                'Call Duration',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _durations.map((dur) {
                  final isSelected = _selectedDuration == dur['sec'];
                  return ChoiceChip(
                    label: Text(dur['label']),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedDuration = dur['sec']);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Notes / Remarks
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Conversation Notes',
                  hintText: 'e.g. Donor interested in child kits, will pay online...',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _submitCallLog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.existingLogId != null
                            ? 'UPDATE CALL LOG IN ADMIN'
                            : 'SAVE CALL LOG TO ADMIN',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
