import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel agent;
  const ProfileScreen({super.key, required this.agent});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _agent;
  bool _isSyncingLocation = false;

  @override
  void initState() {
    super.initState();
    _agent = widget.agent;
  }

  Future<void> _syncLocationNow() async {
    setState(() => _isSyncingLocation = true);
    final success = await LocationService.sendLiveLocationPing();
    setState(() => _isSyncingLocation = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('✓ Live location synchronized with Admin Tracking system!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Failed to get GPS location. Please check location permissions.'),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to sign out of the WeHelp Agent app?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Avatar & Name Card
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      _agent.firstName.isNotEmpty ? _agent.firstName[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _agent.fullName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.secondary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEF7EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'FIELD AGENT • ${_agent.employeeId ?? "AGT-ACTIVE"}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF03543F)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _profileItem(Icons.person_outline_rounded, 'Username', _agent.username),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _profileItem(Icons.badge_outlined, 'Employee ID', _agent.employeeId ?? 'Not Assigned'),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _profileItem(Icons.map_outlined, 'Assigned Territory', _agent.assignedArea ?? 'City General Ward'),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _profileItem(Icons.phone_outlined, 'Contact Phone', _agent.phoneNumber ?? 'Not Provided'),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _profileItem(Icons.email_outlined, 'Email Address', _agent.email.isNotEmpty ? _agent.email : 'agent@wehelp.org'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Location Tracking Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.gps_fixed_rounded, color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Live Admin Location Tracking',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your coordinates are shared with the administrator during duty hours for field coordination.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSyncingLocation ? null : _syncLocationNow,
                      icon: _isSyncingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(_isSyncingLocation ? 'SYNCING GPS...' : 'FORCE SYNC LIVE GPS LOCATION'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('SIGN OUT OF AGENT ACCOUNT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444), // Crimson
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
            ],
          ),
        ),
      ],
    );
  }
}
