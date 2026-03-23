import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  late GoogleSignIn _googleSignIn;

  factory GoogleSignInService() {
    return _instance;
  }

  GoogleSignInService._internal() {
    // Initialize GoogleSignIn
    // iOS configuration is in Info.plist (URL scheme for reversed client ID)
    // Android configuration is in google-services.json and AndroidManifest.xml
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );
  }

  /// Sign in with Google and return ID token
  /// Returns the ID token if successful, null otherwise
  Future<String?> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Return the ID token to send to backend for verification
      return googleAuth.idToken;
    } catch (error) {
      print('Google Sign-In failed: $error');
      rethrow;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      print('Google Sign-Out failed: $error');
      rethrow;
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Get current signed-in user
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}

