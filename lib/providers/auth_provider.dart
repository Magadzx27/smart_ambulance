import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ✅ FIX: tryAutoLogin — يُستدعى من main.dart لاستعادة الجلسة من SharedPreferences
  // عند إغلاق التطبيق وإعادة فتحه يبقى المسعف مسجلاً دون الحاجة لإعادة الدخول
  Future<bool> tryAutoLogin() async {
    await ApiService.loadToken();
    if (ApiService.hasToken) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(phone, password);
      if (response['token'] != null) {
        // ✅ FIX: setToken أصبح async — ينتظر الحفظ في SharedPreferences
        await ApiService.setToken(response['token'] as String);
        _user = response['paramedic'] as Map<String, dynamic>?;
        _isAuthenticated = true;
        return true;
      } else {
        _error = 'بيانات غير صحيحة';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // ✅ FIX: clearToken أصبح async — ينتظر الحذف من SharedPreferences
    await ApiService.clearToken();
    _isAuthenticated = false;
    _user = null;
    _error = null;
    notifyListeners();
  }
}