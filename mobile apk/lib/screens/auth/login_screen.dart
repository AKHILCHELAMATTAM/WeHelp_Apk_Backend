import 'package:flutter/material.dart';
import '../../core/api/api_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/agent_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'agent_rahul');
  final _passwordController = TextEditingController(text: 'Agent@1234');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _currentServerUrl = ApiConstants.defaultBaseUrl;
  int _adminTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final url = await ApiConstants.getBaseUrl();
    if (mounted) {
      setState(() {
        _currentServerUrl = url;
      });
    }
  }

  void _handleAdminSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _adminTapCount = 1;
    } else {
      _adminTapCount++;
    }
    _lastTapTime = now;

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _promptAdminPasscode();
    }
  }

  Future<void> _promptAdminPasscode() async {
    final pinController = TextEditingController();
    final authorized = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Admin Access Required', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server connectivity settings are restricted to system administrators.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Administrator Passcode',
                hintText: 'Enter 4-digit PIN',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (pinController.text.trim() == '9988' || pinController.text.trim() == 'Admin@1234') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.error,
                    content: Text('Invalid administrator passcode.'),
                  ),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (authorized == true && mounted) {
      _showServerSettingsDialog();
    }
  }

  Future<void> _showServerSettingsDialog() async {
    final controller = TextEditingController(text: _currentServerUrl);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server Configuration (Admin)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure the backend server base URL for this client:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend Base URL',
                hintText: 'http://3.110.92.188',
                prefixIcon: Icon(Icons.dns_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => controller.text = 'http://3.110.92.188',
                  child: const Text('AWS EC2', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => controller.text = 'https://wehelp-apk-backend.onrender.com',
                  child: const Text('Render', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => controller.text = 'http://10.0.2.2:8000',
                  child: const Text('Emulator', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiConstants.setBaseUrl(controller.text.trim());
              await _loadServerUrl();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final res = await AuthService.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess && res.data != null) {
      LocationService.sendLiveLocationPing();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AgentHomeScreen(agent: res.data!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Login failed. Please check credentials.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _fillDemoCredentials(String username, String password) {
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // Brand Hero Icon & Header (tapping 5 times unlocks secret admin setup)
                  Center(
                    child: GestureDetector(
                      onTap: _handleAdminSecretTap,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.volunteer_activism_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'WeHelp Foundation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.secondary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Field Agent Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Agent Username',
                      hintText: 'e.g. agent_rahul',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your assigned username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Login submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'SIGN IN AS AGENT',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Quick two-agent credentials selector
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 6),
                            Text(
                              'Select Agent Login Account:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Agent 1: agent_rahul
                            Expanded(
                              child: InkWell(
                                onTap: () => _fillDemoCredentials('agent_rahul', 'Agent@1234'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _usernameController.text == 'agent_rahul'
                                        ? const Color(0xFFECFDF5)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _usernameController.text == 'agent_rahul'
                                          ? AppTheme.primary
                                          : const Color(0xFFCBD5E1),
                                      width: _usernameController.text == 'agent_rahul' ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.account_circle,
                                            size: 16,
                                            color: _usernameController.text == 'agent_rahul'
                                                ? AppTheme.primary
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          const Flexible(
                                            child: Text(
                                              'agent_rahul',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Pass: Agent@1234',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Agent 2: agent_priya
                            Expanded(
                              child: InkWell(
                                onTap: () => _fillDemoCredentials('agent_priya', 'Agent@1234'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _usernameController.text == 'agent_priya'
                                        ? const Color(0xFFECFDF5)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _usernameController.text == 'agent_priya'
                                          ? AppTheme.primary
                                          : const Color(0xFFCBD5E1),
                                      width: _usernameController.text == 'agent_priya' ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.account_circle,
                                            size: 16,
                                            color: _usernameController.text == 'agent_priya'
                                                ? AppTheme.primary
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          const Flexible(
                                            child: Text(
                                              'agent_priya',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Pass: Agent@1234',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
