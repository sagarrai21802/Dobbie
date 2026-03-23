import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  Future<void> checkAuthStatus() async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user;
        _state = AuthState.authenticated;
      } else {
        final hasAnyToken = await _authService.isLoggedIn();
        if (hasAnyToken) {
          _state = AuthState.error;
          _errorMessage = 'Session check failed. Please retry.';
        } else {
          _user = null;
          _state = AuthState.unauthenticated;
        }
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _user = null;
        _state = AuthState.unauthenticated;
      } else {
        _state = AuthState.error;
        _errorMessage = 'Network/server issue. Please try again.';
      }
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Unable to verify session right now.';
    }
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.login(email: email, password: password);
      _user = await _authService.getCurrentUser();
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please check your internet.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.googleSignIn();
      _user = await _authService.getCurrentUser();
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Google Sign-In failed. Please try again.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
      );

      await _authService.login(email: email, password: password);
      _user = await _authService.getCurrentUser();
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please check your internet.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _state = AuthState.loading;
    notifyListeners();

    await _authService.logout();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }
}
