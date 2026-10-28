import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_log_model.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Dialpad state
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();

  // Data state
  bool _isLoadingSummary = false;
  bool _isLoadingLeads = false;
  bool _isLoadingLogs = false;
  CallSummaryModel? _summary;
  List<TelemarketingLeadModel> _leads = [];
  List<CallLogModel> _callLogs = [];

  // Filter state for Leads
  String _leadSearchQuery = '';
  String _selectedLeadCategory = 'ALL';

  // Filter state for Call Logs
  String _logFilterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialPhoneNumber != null) {
      _phoneController.text = widget.initialPhoneNumber!;
    }
    if (widget.initialContactName != null) {
      _contactNameController.text = widget.initialContactName!;
    }
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _contactNameController.dispose();
    super.dispose();
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

  // Dial & Launch Call
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

    // Automatically pop the Call Outcome sheet so staff can record the conversation details
    if (mounted) {
      _showCallOutcomeSheet(
        phoneNumber: cleanPhone,
        contactName: name.isNotEmpty ? name : 'Contact ($cleanPhone)',
      );
    }
  }

  // Modal Sheet for Logging Call Outcome
  void _showCallOutcomeSheet({
    required String phoneNumber,
    required String contactName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CallOutcomeSheet(
        phoneNumber: phoneNumber,
        contactName: contactName,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 12),

          // Main Number Display Screen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      fontSize: 24,
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
          const SizedBox(height: 16),

          // Keypad Grid
          _buildKeypad(),
          const SizedBox(height: 18),

          // Bottom Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Clear All
              if (_phoneController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded, color: Colors.grey),
                  tooltip: 'Clear',
                  onPressed: _onClearPressed,
                ),

              const SizedBox(width: 12),

              // Large Call Button
              ElevatedButton(
                onPressed: () {
                  final phone = _phoneController.text.trim();
                  final name = _contactNameController.text.trim();
                  _initiateCall(phone, name);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E9F6E), // Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'CALL NOW',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Direct Log Outcome Button
              IconButton(
                icon: const Icon(Icons.post_add_rounded, color: AppTheme.primary),
                tooltip: 'Log Call Outcome',
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
        childAspectRatio: 1.55,
        crossAxisSpacing: 14,
        mainAxisSpacing: 10,
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
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        onLongPress: digit == '0' ? () => _onDigitPressed('+') : null,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.primary.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                digit,
                style: const TextStyle(
                  fontSize: 24,
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
                                  // Call Button
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
    } else if (status == 'CALLBACK') {
      bg = const Color(0xFFFEF08A);
      fg = const Color(0xFF854D0E);
    } else if (status == 'IN_PROGRESS') {
      bg = const Color(0xFFE1EFFE);
      fg = const Color(0xFF1E429F);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        display,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 3: CALL LOGS (HISTORY)
  // ----------------------------------------------------
  Widget _buildCallLogsTab() {
    final filteredLogs = _callLogs.where((log) {
      if (_logFilterStatus == 'ALL') return true;
      if (_logFilterStatus == 'CONNECTED') return log.isConnected;
      if (_logFilterStatus == 'PLEDGED') return log.isPledged;
      if (_logFilterStatus == 'CALLBACK') return log.isCallback;
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
                                            Text(
                                              log.phoneNumber,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
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
                                          const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            log.formattedDuration,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          if (log.pledgedAmount > 0) ...[
                                            const SizedBox(width: 12),
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
// BOTTOM SHEET MODAL: LOG CALL OUTCOME
// ----------------------------------------------------
class _CallOutcomeSheet extends StatefulWidget {
  final String phoneNumber;
  final String contactName;
  final VoidCallback onLogSaved;

  const _CallOutcomeSheet({
    required this.phoneNumber,
    required this.contactName,
    required this.onLogSaved,
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
  int _selectedDuration = 60; // seconds
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

    final res = await ApiClient.post(ApiConstants.callLogs, body: payload);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res.isSuccess) {
      Navigator.pop(context);
      widget.onLogSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0E9F6E),
          content: Text('Call log recorded successfully and sent to Admin Panel!'),
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

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Record Call Outcome',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                    ),
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

              // Call Duration Selector
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
                    : const Text(
                        'SAVE CALL LOG TO ADMIN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
