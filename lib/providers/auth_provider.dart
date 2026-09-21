import 'package:flutter/material.dart';
import '../services/pb_service.dart';
import '../main.dart';

class AuthProvider extends ChangeNotifier {
  final PBService _pb = PBService();
  bool _isLoading = false;
  String? _error;
  String _serverUrl = 'https://marketdarwaza.duckdns.org';

  /// Set to true when the user was kicked out due to deactivation.
  bool _wasDeactivated = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _pb.isLoggedIn;
  String get serverUrl => _serverUrl;
  bool get wasDeactivated => _wasDeactivated;

  // User info
  String? get currentUserId => _pb.currentUserId;
  String? get currentUserName => _pb.currentUserName;
  String? get currentUserRole => _pb.currentUserRole;
  bool get isAdmin => _pb.isAdmin;

  /// Background token refresh — called after UI is up.
  Future<void> backgroundRefresh() async {
    await _pb.tryRefreshAuth();
    if (_pb.isLoggedIn) {
      _subscribeToUserChanges();
    }
    notifyListeners();
  }

  void _subscribeToUserChanges() {
    try {
      _pb.subscribeCurrentUser(() async {
        _pb.unsubscribeCurrentUser();
        _wasDeactivated = true;
        _error = 'هەژمارەکەت لەلایەن ئەدمینەوە ناچالاک کرا';
        // Pop all routes back to AuthGate before triggering auth change
        MarketDarwazaApp.navigatorKey.currentState
            ?.popUntil((route) => route.isFirst);
        await _pb.logout();
        notifyListeners();
      });
    } catch (_) {}
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    await _pb.setServerUrl(url);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    _wasDeactivated = false;
    notifyListeners();

    try {
      final result = await _pb.login(email, password);
      if (result == 'deactivated') {
        _error = 'هەژمارەکەت ناچالاک کراوە، تکایە پەیوەندی بە بەڕێوەبەر بکە';
        _wasDeactivated = true;
      } else if (result != 'ok') {
        _error = 'ئیمەیڵ یان وشەی نهێنی هەڵەیە';
      } else {
        _subscribeToUserChanges();
        // Log the login activity
        await _pb.logActivity(
          actionType: 'login',
          entityType: 'user',
          description: '${_pb.currentUserName} چووە ژوورەوە',
        );
      }
      _isLoading = false;
      notifyListeners();
      return result == 'ok';
    } catch (e) {
      _error = 'هەڵە لە پەیوەندیکردن بە سێرڤەر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _pb.changeOwnPassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _pb.unsubscribeCurrentUser();
    await _pb.logout();
    notifyListeners();
  }

  /// Permanently deletes the current user's account and signs out.
  Future<void> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _pb.deleteOwnAccount();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete account. Please try again.';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
