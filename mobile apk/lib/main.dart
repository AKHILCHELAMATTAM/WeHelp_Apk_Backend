import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/auth_service.dart';
import 'core/services/location_service.dart';
import 'core/theme/app_theme.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/agent_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Check login state
  final loggedIn = await AuthService.isLoggedIn();
  UserModel? cachedUser;
  if (loggedIn) {
    cachedUser = await AuthService.getCachedUser();
    // Fire background live location update on app launch
    LocationService.sendLiveLocationPing();
  }

  runApp(WeHelpAgentApp(
    isLoggedIn: loggedIn && cachedUser != null,
    initialUser: cachedUser,
  ));
}

class WeHelpAgentApp extends StatelessWidget {
  final bool isLoggedIn;
  final UserModel? initialUser;

  const WeHelpAgentApp({
    super.key,
    required this.isLoggedIn,
    this.initialUser,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeHelp Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isLoggedIn && initialUser != null
          ? AgentHomeScreen(agent: initialUser!)
          : const LoginScreen(),
    );
  }
}
