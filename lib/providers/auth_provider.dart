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

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await ApiService.login(phone, password);
      if (response['token'] != null) {
        ApiService.setToken(response['token']);
        _user = response['paramedic'];
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

  void logout() {
    ApiService.clearToken();
    _isAuthenticated = false;
    _user = null;
    _error = null;
    notifyListeners();
  }
}