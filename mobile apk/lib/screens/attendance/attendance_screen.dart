import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_model.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  AttendanceRecord? _todayRecord;
  DailyTargetProgress? _targetProgress;
  List<AttendanceRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchStatus(),
      _fetchDailyTarget(),
      _fetchHistory(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchStatus() async {
    final res = await ApiClient.get(ApiConstants.attendanceStatus);
    if (res.isSuccess && res.data != null) {
      final attData = res.data['attendance'];
      if (attData != null) {
        setState(() {
          _todayRecord = AttendanceRecord.fromJson(attData);
        });
      } else {
        setState(() {
          _todayRecord = null;
        });
      }
    }
  }

  Future<void> _fetchDailyTarget() async {
    final res = await ApiClient.get(ApiConstants.todayTarget);
    if (res.isSuccess && res.data != null) {
      setState(() {
        _targetProgress = DailyTargetProgress.fromJson(res.data);
      });
    }
  }

  Future<void> _fetchHistory() async {
    final res = await ApiClient.get(ApiConstants.attendanceHistory);
    if (res.isSuccess && res.data != null && res.data is List) {
      setState(() {
        _history = (res.data as List)
            .map((item) => AttendanceRecord.fromJson(item))
            .toList();
      });
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isActionLoading = true);

    // 1. Get exact GPS location with agent consent
    final loc = await LocationService.getCurrentLocation();
    if (loc == null) {
      setState(() => _isActionLoading = false);
      if (!mounted) return;
      _showGpsErrorDialog();
      return;
    }

    // 2. Submit check-in to backend
    final res = await ApiClient.post(
      ApiConstants.checkIn,
      body: {
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'accuracy': loc.accuracy,
        'address': loc.address,
        'notes': 'Mobile app check-in',
      },
    );

    setState(() => _isActionLoading = false);

    if (!mounted) return;

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('✓ Checked in successfully with exact GPS location!'),
        ),
      );
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Check-in failed'),
        ),
      );
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isActionLoading = true);

    final loc = await LocationService.getCurrentLocation();
    if (loc == null) {
      setState(() => _isActionLoading = false);
      if (!mounted) return;
      _showGpsErrorDialog();
      return;
    }

    final res = await ApiClient.post(
      ApiConstants.checkOut,
      body: {
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'accuracy': loc.accuracy,
        'address': loc.address,
        'notes': 'Shift completed via mobile app',
      },
    );

    setState(() => _isActionLoading = false);

    if (!mounted) return;

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('✓ Checked out successfully. Good job today!'),
        ),
      );
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Check-out failed'),
        ),
      );
    }
  }

  void _showGpsErrorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text(
          'Please enable Location Services (GPS) and grant permission to mark your attendance accurately.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoogleMap(String? mapUrl) async {
    if (mapUrl == null || mapUrl.isEmpty) return;
    final uri = Uri.parse(mapUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map: $mapUrl')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final isCheckedIn = _todayRecord?.checkInTime != null;
    final isCheckedOut = _todayRecord?.checkOutTime != null;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isCheckedIn ? AppTheme.primary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isCheckedIn ? AppTheme.primary : Colors.grey).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCheckedOut
                                    ? Icons.task_alt_rounded
                                    : (isCheckedIn ? Icons.access_time_filled_rounded : Icons.pending_actions_rounded),
                                color: isCheckedIn ? AppTheme.primary : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isCheckedOut
                                      ? 'Completed Shift'
                                      : (isCheckedIn ? 'Currently on Duty' : 'Not Checked In Yet'),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCheckedIn ? const Color(0xFFDEF7EC) : const Color(0xFFFEF08A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCheckedOut ? 'CHECKED OUT' : (isCheckedIn ? 'PRESENT' : 'PENDING'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCheckedIn ? const Color(0xFF03543F) : const Color(0xFF854D0E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

                    // Check-in and out timestamps
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CHECK-IN TIME', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                _todayRecord?.checkInTime != null
                                    ? DateFormat('hh:mm a').format(DateTime.parse(_todayRecord!.checkInTime!).toLocal())
                                    : '--:--',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CHECK-OUT TIME', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                _todayRecord?.checkOutTime != null
                                    ? DateFormat('hh:mm a').format(DateTime.parse(_todayRecord!.checkOutTime!).toLocal())
                                    : '--:--',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Map link button if checked in
                    if (_todayRecord?.checkInGoogleMapLink != null) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => _openGoogleMap(_todayRecord!.checkInGoogleMapLink),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Checked in at: ${_todayRecord?.checkInAddress ?? "Exact GPS Location"}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF1D4ED8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Check In / Check Out Action Button
            if (!isCheckedIn) ...[
              ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _handleCheckIn,
                icon: _isActionLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.touch_app_rounded, size: 22),
                label: Text(
                  _isActionLoading ? 'ACQUIRING GPS & CHECKING IN...' : 'MARK CHECK-IN ATTENDANCE',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else if (!isCheckedOut) ...[
              ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _handleCheckOut,
                icon: _isActionLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.logout_rounded, size: 22),
                label: Text(
                  _isActionLoading ? 'RECORDING CHECK-OUT...' : 'MARK CHECK-OUT FOR TODAY',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309), // Amber-Brown
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Attendance completed for today.',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Today's Target Card
            if (_targetProgress != null) ...[
              const Text(
                "Today's Daily Target",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondary),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Cash Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cash Collection Target:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '₹${_targetProgress!.achievedCashAmount.toStringAsFixed(0)} / ₹${_targetProgress!.targetCashAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_targetProgress!.targetCashAmount > 0)
                              ? (_targetProgress!.achievedCashAmount / _targetProgress!.targetCashAmount).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Product Units Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Product Units Target:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '${_targetProgress!.achievedProductUnits.toStringAsFixed(0)} / ${_targetProgress!.targetProductUnits.toStringAsFixed(0)} Units',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_targetProgress!.targetProductUnits > 0)
                              ? (_targetProgress!.achievedProductUnits / _targetProgress!.targetProductUnits).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // History Header
            const Text(
              'Past Attendance History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondary),
            ),
            const SizedBox(height: 10),

            if (_history.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No previous records found.', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length > 5 ? 5 : _history.length,
                itemBuilder: (ctx, index) {
                  final record = _history[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF4338CA)),
                      ),
                      title: Text(record.date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        record.checkInTime != null
                            ? 'In: ${DateFormat("hh:mm a").format(DateTime.parse(record.checkInTime!).toLocal())}'
                            : 'No In Time',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: record.checkInGoogleMapLink != null
                          ? IconButton(
                              icon: const Icon(Icons.location_on_rounded, color: AppTheme.primary),
                              onPressed: () => _openGoogleMap(record.checkInGoogleMapLink),
                              tooltip: 'Open in Google Maps',
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
