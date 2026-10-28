import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_constants.dart';

class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int statusCode;

  ApiResponse({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    required this.statusCode,
  });
}

class ApiClient {
  static Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.prefsTokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<ApiResponse<dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } on SocketException {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'Network error. Please check your internet connection.',
      );
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 500,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  static Future<ApiResponse<dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      final response = await http
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } on SocketException {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'Cannot connect to server. Please verify your network.',
      );
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 500,
        errorMessage: 'Request failed: ${e.toString()}',
      );
    }
  }

  static Future<ApiResponse<dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      final response = await http
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } on SocketException {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'Cannot connect to server. Please verify your network.',
      );
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 500,
        errorMessage: 'Request failed: ${e.toString()}',
      );
    }
  }

  static ApiResponse<dynamic> _processResponse(http.Response response) {
    dynamic decodedData;
    try {
      if (response.body.isNotEmpty) {
        decodedData = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {
      decodedData = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse(
        isSuccess: true,
        data: decodedData,
        statusCode: response.statusCode,
      );
    } else {
      String errorMessage = 'Request failed (${response.statusCode})';

      if (decodedData is Map) {
        if (decodedData.containsKey('detail')) {
          final detail = decodedData['detail'];
          errorMessage = detail is List ? detail.join(', ') : detail.toString();
        } else if (decodedData.containsKey('message')) {
          errorMessage = decodedData['message'].toString();
        } else if (decodedData.isNotEmpty) {
          // Flatten field error lists
          final errors = <String>[];
          decodedData.forEach((key, val) {
            if (val is List) {
              errors.add('$key: ${val.join(", ")}');
            } else {
              errors.add('$key: $val');
            }
          });
          if (errors.isNotEmpty) {
            errorMessage = errors.join('\n');
          }
        }
      }

      return ApiResponse(
        isSuccess: false,
        data: decodedData,
        errorMessage: errorMessage,
        statusCode: response.statusCode,
      );
    }
  }
}
