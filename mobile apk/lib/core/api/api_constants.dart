import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  // Default EC2 production server URL
  static const String defaultBaseUrl = "http://3.110.92.188";
  static const String prefsBaseUrlKey = "custom_base_url";
  static const String prefsTokenKey = "jwt_access_token";
  static const String prefsRefreshTokenKey = "jwt_refresh_token";
  static const String prefsUserDataKey = "cached_user_data";

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(prefsBaseUrlKey);
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    return defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(prefsBaseUrlKey, cleanUrl);
  }

  // Endpoints (all end with trailing slash to prevent Django APPEND_SLASH 500s)
  static const String login = "/api/auth/login/";
  static const String profile = "/api/auth/profile/";
  static const String refreshToken = "/api/auth/token/refresh/";

  // Agent Tracking
  static const String sendLocation = "/api/agent/location/";
  static const String latestLocation = "/api/agent/location/latest/";

  // Agent Attendance
  static const String checkIn = "/api/agent/attendance/check-in/";
  static const String checkOut = "/api/agent/attendance/check-out/";
  static const String attendanceStatus = "/api/agent/attendance/status/";
  static const String attendanceHistory = "/api/agent/attendance/history/";
  static const String todayTarget = "/api/agent/target/today/";

  // Agent Donations & Collections
  static const String cashDonation = "/api/agent/donations/cash/";
  static const String productDonation = "/api/agent/donations/product/";
  static const String donationsList = "/api/agent/donations/";
  static const String donationsSummary = "/api/agent/donations/summary/";
  static const String bankDetails = "/api/agent/bank-details/";

  // Agent Leaves & Requests
  static const String leaveRequests = "/api/agent/leaves/";

  // Telemarketing Dialer & Call Logs
  static const String callLogs = "/api/agent/calls/";
  static const String callSummary = "/api/agent/calls/summary/";
  static const String telemarketingLeads = "/api/agent/telemarketing/leads/";
  static const String adminCallLogs = "/api/admin/calls/";
  static const String adminCallSummary = "/api/admin/calls/summary/";
}
