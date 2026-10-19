import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/api_constants.dart';
import '../../models/user_model.dart';

class AuthService {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.prefsTokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(ApiConstants.prefsUserDataKey);
    if (userJson != null) {
      try {
        return UserModel.fromJson(jsonDecode(userJson));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<ApiResponse<UserModel>> login({
    required String username,
    required String password,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.login,
      body: {
        'username': username.trim(),
        'password': password,
        'role': 'AGENT',
      },
      requiresAuth: false,
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>?;
      if (tokens != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConstants.prefsTokenKey, tokens['access'] ?? '');
        await prefs.setString(ApiConstants.prefsRefreshTokenKey, tokens['refresh'] ?? '');
      }

      // Fetch full profile immediately
      final profileRes = await fetchProfile();
      if (profileRes.isSuccess && profileRes.data != null) {
        return profileRes;
      }

      // Fallback minimal model if profile fetch fails
      return ApiResponse(
        isSuccess: true,
        statusCode: response.statusCode,
        data: UserModel(
          id: 0,
          username: username,
          email: '',
          firstName: username,
          lastName: '',
          role: 'AGENT',
        ),
      );
    }

    return ApiResponse(
      isSuccess: false,
      statusCode: response.statusCode,
      errorMessage: response.errorMessage ?? 'Login failed. Please check credentials.',
    );
  }

  static Future<ApiResponse<UserModel>> fetchProfile() async {
    final response = await ApiClient.get(ApiConstants.profile);
    if (response.isSuccess && response.data != null) {
      final user = UserModel.fromJson(response.data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.prefsUserDataKey, jsonEncode(user.toJson()));
      return ApiResponse(
        isSuccess: true,
        statusCode: response.statusCode,
        data: user,
      );
    }
    return ApiResponse(
      isSuccess: false,
      statusCode: response.statusCode,
      errorMessage: response.errorMessage,
    );
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.prefsTokenKey);
    await prefs.remove(ApiConstants.prefsRefreshTokenKey);
    await prefs.remove(ApiConstants.prefsUserDataKey);
  }
}
