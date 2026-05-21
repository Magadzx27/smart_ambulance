import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ambulance_request.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  // ✅ FIX: baseUrl قابل للتغيير — غيّره لرابط السيرفر الفعلي عند الرفع
  static const String baseUrl = 'http://192.168.8.117:8000/api';
  static const String _tokenKey = 'auth_token';
  static String? _token;
  static const int timeoutSeconds = 15;

  // ✅ FIX: تحميل التوكن من SharedPreferences عند بدء التطبيق
  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static bool get hasToken => _token != null;

  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<dynamic> _handleRequest(
      Future<http.Response> Function() request) async {
    try {
      final response = await request()
          .timeout(const Duration(seconds: timeoutSeconds));
      final decoded = jsonDecode(response.body);

      switch (response.statusCode) {
        case 200:
        case 201:
          return decoded;
        case 400:
        // ✅ FIX: 400 = موقع المسعف غير محدَّث — رسالة واضحة للمستخدم
          throw ApiException(
              decoded['message'] ?? 'يرجى تفعيل الموقع الجغرافي أولاً');
        case 401:
        // ✅ FIX: 401 قد يعني انتهاء التوكن أيضاً وليس فقط بيانات خاطئة
          throw ApiException(
              decoded['message'] ?? 'انتهت الجلسة، يرجى تسجيل الدخول مجدداً');
        case 422:
        // ✅ FIX: استخراج أول خطأ تفصيلي من errors إن وُجد
          final errors = decoded['errors'] as Map<String, dynamic>?;
          final firstError = errors?.values.firstOrNull;
          final errorMsg = (firstError is List && firstError.isNotEmpty)
              ? firstError.first.toString()
              : decoded['message'] ?? 'بيانات غير صالحة';
          throw ApiException(errorMsg);
        case 500:
          throw ApiException('حدث خطأ في الخادم، حاول لاحقاً');
        default:
          throw ApiException(
              decoded['message'] ?? 'حدث خطأ غير متوقع (${response.statusCode})');
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

  // ✅ Login — /paramedic/login (POST) — موثق في API
  static Future<Map<String, dynamic>> login(
      String phone, String password) async {
    return await _handleRequest(() => http.post(
      Uri.parse('$baseUrl/paramedic/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'password': password}),
    ));
  }

  // ✅ FIX: حُذف getProfile() — لا يوجد endpoint له في الـ API docs

  // ✅ Update Location — /paramedic/update-location (POST) — موثق في API
  static Future<Map<String, dynamic>> updateLocation(
      double lat, double lng) async {
    return await _handleRequest(() => http.post(
      Uri.parse('$baseUrl/paramedic/update-location'),
      headers: _headers,
      body: jsonEncode({'lat': lat, 'lng': lng}),
    ));
  }

  // ✅ Search Hospitals — /hospitals/search (GET) — موثق في API
  // ✅ FIX: case_description اختياري — لا يُرسَل إذا كان فارغاً
  static Future<List<Hospital>> searchHospitals(
      String caseClassification, String caseDescription) async {
    final params = <String, String>{
      'case_classification': caseClassification,
      if (caseDescription.isNotEmpty) 'case_description': caseDescription,
    };
    final uri =
    Uri.parse('$baseUrl/hospitals/search').replace(queryParameters: params);

    final data = await _handleRequest(() => http.get(uri, headers: _headers));

    // ✅ FIX: استخدام Uri.replace لبناء الـ query بدلاً من string concatenation
    if (data['results'] != null) {
      return (data['results'] as List)
          .map((h) => Hospital.fromJson(h as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // ✅ Get My Requests — /ambulance-requests (GET) — موثق في API
  static Future<List<RequestStatus>> getMyRequests() async {
    final data = await _handleRequest(() => http.get(
      Uri.parse('$baseUrl/ambulance-requests'),
      headers: _headers,
    ));
    if (data['requests'] != null) {
      return (data['requests'] as List)
          .map((r) => RequestStatus.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // ✅ Send Request — /ambulance-requests (POST) — موثق في API
  static Future<Map<String, dynamic>> sendRequest(
      AmbulanceRequest request) async {
    return await _handleRequest(() => http.post(
      Uri.parse('$baseUrl/ambulance-requests'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    ));
  }
}