import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_model.dart';
import '../../models/donation_model.dart';
import '../../models/user_model.dart';
import '../attendance/attendance_screen.dart';
import '../donations/donation_collection_screen.dart';
import '../donations/product_collection_screen.dart';
import '../profile/profile_screen.dart';
import '../requests/supply_requests_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  final UserModel agent;
  const AgentHomeScreen({super.key, required this.agent});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  int _currentIndex = 0;
  late UserModel _agent;
  Timer? _locationTimer;

  DonationsSummary? _summary;
  DailyTargetProgress? _todayTarget;
  AttendanceRecord? _todayAttendance;
  List<DonationRecord> _recentDonations = [];

  @override
  void initState() {
    super.initState();
    _agent = widget.agent;
    _loadDashboardData();

    // Periodic live location reporting (every 3 minutes) as per requirements #2 & #3
    // Admin application tracks agent's live location when app is opened
    LocationService.sendLiveLocationPing();
    _locationTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      LocationService.sendLiveLocationPing();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    await Future.wait([
      _fetchDonationsSummary(),
      _fetchDailyTarget(),
      _fetchAttendanceStatus(),
      _fetchRecentDonations(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _fetchDonationsSummary() async {
    final res = await ApiClient.get(ApiConstants.donationsSummary);
    if (res.isSuccess && res.data != null) {
      setState(() {
        _summary = DonationsSummary.fromJson(res.data);
      });
    }
  }

  Future<void> _fetchDailyTarget() async {
    final res = await ApiClient.get(ApiConstants.todayTarget);
    if (res.isSuccess && res.data != null) {
      setState(() {
        _todayTarget = DailyTargetProgress.fromJson(res.data);
      });
    }
  }

  Future<void> _fetchAttendanceStatus() async {
    final res = await ApiClient.get(ApiConstants.attendanceStatus);
    if (res.isSuccess && res.data != null) {
      final attData = res.data['attendance'];
      if (attData != null) {
        setState(() {
          _todayAttendance = AttendanceRecord.fromJson(attData);
        });
      }
    }
  }

  Future<void> _fetchRecentDonations() async {
    final res = await ApiClient.get(ApiConstants.donationsList);
    if (res.isSuccess && res.data != null && res.data is List) {
      setState(() {
        _recentDonations = (res.data as List)
            .map((item) => DonationRecord.fromJson(item))
            .take(5)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 5 primary navigation tabs
    final pages = [
      _buildHomeDashboardTab(),
      const AttendanceScreen(),
      const DonationCollectionScreen(),
      const ProductCollectionScreen(),
      const SupplyRequestsScreen(),
    ];

    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              title: Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WeHelp Field Agent',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _agent.assignedArea ?? 'General Area',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Data',
                  onPressed: _loadDashboardData,
                ),
                IconButton(
                  icon: const Icon(Icons.account_circle_rounded),
                  tooltip: 'Agent Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(agent: _agent),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.co_present_rounded),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Donate QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_rounded),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Requests',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDashboardTab() {
    final isCheckedIn = _todayAttendance?.checkInTime != null;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Tracking Active Banner (Requirement #2 & #3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFDEF7EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF84E1BC)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, color: Color(0xFF03543F), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live GPS Tracking Active • Admin Connected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF03543F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Welcome Greeting & Agent Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF064E3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${_agent.firstName}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${_agent.employeeId ?? "AGT-ACTIVE"}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          isCheckedIn ? 'ON DUTY' : 'NOT CHECKED IN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricItem(
                          'Today Cash',
                          '₹${_summary?.todayCashTotal.toStringAsFixed(0) ?? "0"}',
                          Icons.currency_rupee_rounded,
                        ),
                        Container(width: 1, height: 30, color: Colors.white24),
                        _metricItem(
                          'Products',
                          '${_summary?.todayProductTotalQuantity.toStringAsFixed(0) ?? "0"} kg',
                          Icons.inventory_2_rounded,
                        ),
                        Container(width: 1, height: 30, color: Colors.white24),
                        _metricItem(
                          'Donations',
                          '${_summary?.totalDonationsToday ?? 0}',
                          Icons.receipt_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Daily Target Progress Ring / Bar
            if (_todayTarget != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Goal Progress",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondary),
                          ),
                          Text(
                            '${_todayTarget!.cashCompletionPercentage.toStringAsFixed(0)}% Completed',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_todayTarget!.cashCompletionPercentage / 100.0).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cash: ₹${_todayTarget!.achievedCashAmount.toStringAsFixed(0)} / ₹${_todayTarget!.targetCashAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          Text(
                            'Items: ${_todayTarget!.achievedProductUnits.toStringAsFixed(0)} / ${_todayTarget!.targetProductUnits.toStringAsFixed(0)} units',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Quick Actions Title
            const Text(
              'Field Operations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondary),
            ),
            const SizedBox(height: 12),

            // 4 Core Action Tiles Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _actionCard(
                  title: 'Mark Attendance',
                  subtitle: isCheckedIn ? 'Checked In' : 'Check In GPS',
                  icon: Icons.fingerprint_rounded,
                  color: isCheckedIn ? AppTheme.primary : AppTheme.accent,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _actionCard(
                  title: 'Collect Donation',
                  subtitle: 'UPI QR & Cash',
                  icon: Icons.qr_code_2_rounded,
                  color: const Color(0xFF2563EB), // Blue
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _actionCard(
                  title: 'Sales & Products',
                  subtitle: 'Groceries & Goods',
                  icon: Icons.shopping_basket_rounded,
                  color: const Color(0xFF059669), // Green
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _actionCard(
                  title: 'Supply Requests',
                  subtitle: 'Kits, Bags, Leave',
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFF7C3AED), // Purple
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Collections Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Field Entries',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_recentDonations.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Colors.grey.shade400, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          'No donations logged yet today.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentDonations.length,
                itemBuilder: (ctx, idx) {
                  final item = _recentDonations[idx];
                  final isProduct = item.donationType == 'PRODUCT';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (isProduct ? AppTheme.accent : AppTheme.primary).withValues(alpha: 0.12),
                        child: Icon(
                          isProduct ? Icons.inventory_2_rounded : Icons.currency_rupee_rounded,
                          color: isProduct ? AppTheme.accent : AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        isProduct ? '${item.productName} (${item.quantity} ${item.unit})' : item.donorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '#${item.receiptNumber} • ${item.paymentMode}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: Text(
                        isProduct
                            ? (item.estimatedValue != null ? '₹${item.estimatedValue!.toStringAsFixed(0)}' : 'Product')
                            : '₹${item.amount?.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondary),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
