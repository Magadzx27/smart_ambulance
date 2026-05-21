import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ambulance_request.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static String? _token;
  static const int timeoutSeconds = 15;

  static void setToken(String token) => _token = token;
  static void clearToken() => _token = null;

  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<dynamic> _handleRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: timeoutSeconds));
      final decoded = jsonDecode(response.body);

      switch (response.statusCode) {
        case 200:
        case 201:
          return decoded;
        case 400:
          throw ApiException(decoded['message'] ?? 'طلب غير صالح');
        case 401:
          throw ApiException('رقم الهاتف أو كلمة المرور غير صحيحة');
        case 422:
          throw ApiException(decoded['message'] ?? 'بيانات غير صالحة');
        case 500:
          throw ApiException('حدث خطأ في الخادم');
        default:
          throw ApiException(decoded['message'] ?? 'حدث خطأ غير متوقع');
      }
    } on SocketException {
      throw ApiException('تحقق من اتصال الإنترنت');
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال بالخادم');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('حدث خطأ: $e');
    }
  }

  static Future<Map<String, dynamic>> login(String phone, String password) async {
    return await _handleRequest(() => http.post(
      Uri.parse('$baseUrl/paramedic/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'password': password}),
    ));
  }

  static Future<Map<String, dynamic>> getProfile() async {
    return await _handleRequest(() => http.get(
      Uri.parse('$baseUrl/paramedic/profile'),
      headers: _headers,
    ));
  }

  static Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    return await _handleRequest(() => http.post(
      Uri.parse('$baseUrl/paramedic/update-location'),
      headers: _headers,
      body: jsonEncode({'lat': lat, 'lng': lng}),
    ));
  }

  static Future<List<Hospital>> searchHospitals(String caseClassification, String caseDescription) async {
    final queryParams = [
      'case_classification=${Uri.encodeComponent(caseClassification)}',
      if (caseDescription.isNotEmpty) 'case_description=${Uri.encodeComponent(caseDescription)}'
    ].join('&');
    
    final data = await _handleRequest(() => http.get(
      Uri.parse('$baseUrl/hospitals/search?$queryParams'),
      headers: _headers,
    ));
    if (data['results'] != null) {
      return (data['results'] as List).map((h) => Hospital.fromJson(h)).toList();
    }
    return [];
  }

  static Future<List<RequestStatus>> getMyRequests() async {
    final data = await _handleRequest(() => http.get(
      Uri.parse('$baseUrl/ambulance-requests'),
      headers: _headers,
    ));
    if (data['requests'] != null) {
      return (data['requests'] as List).map((r) => RequestStatus.fromJson(r)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> sendRequest(AmbulanceRequest request) async {
    return await _handleRequest(() => http.post(
      Uri.parse('$baseUrl/ambulance-requests'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    ));
  }
}