import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:proyek_amankanjalan/models/user_model.dart';

class FirebaseService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // ===== AUTHENTICATION METHODS =====

  /// Login dengan email dan password
  Future<firebase_auth.User?> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      firebase_auth.UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Register/Sign Up dengan email dan password
  Future<firebase_auth.User?> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String phoneNumber,
  }) async {
    try {
      firebase_auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      firebase_auth.User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Buat data user di Realtime Database
        await createUserInDatabase(
          uid: firebaseUser.uid,
          email: email,
          fullName: fullName,
          username: username,
          phoneNumber: phoneNumber,
        );
      }

      return firebaseUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Gagal logout: $e';
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Get current user
  firebase_auth.User? getCurrentFirebaseUser() {
    return _auth.currentUser;
  }

  /// Stream untuk monitor perubahan auth state
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // ===== DATABASE METHODS =====

  /// Buat user data di Realtime Database
  Future<void> createUserInDatabase({
    required String uid,
    required String email,
    required String fullName,
    required String username,
    required String phoneNumber,
  }) async {
    try {
      final userRef = _database.ref('users/$uid');
      
      final userData = {
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'username': username,
        'phoneNumber': phoneNumber,
        'photoUrl': null,
        'createdAt': DateTime.now().toIso8601String(),
        'reportCount': 0,
        'upvoteCount': 0,
      };

      await userRef.set(userData);
    } catch (e) {
      throw 'Gagal membuat data user: $e';
    }
  }

  /// Get user data dari Database
  Future<User?> getUserData({required String uid}) async {
    try {
      final userRef = _database.ref('users/$uid');
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        return User.fromJson(Map<String, dynamic>.from(snapshot.value as Map));
      }
      return null;
    } catch (e) {
      throw 'Gagal mengambil data user: $e';
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? username,
    String? photoUrl,
  }) async {
    try {
      final userRef = _database.ref('users/$uid');
      
      Map<String, dynamic> updateData = {};
      if (username != null) updateData['username'] = username;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;

      await userRef.update(updateData);
    } catch (e) {
      throw 'Gagal mengupdate profil: $e';
    }
  }

  // ===== HELPER METHODS =====

  /// Handle Firebase Auth Exception
  String _handleAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
        return 'Password salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan login. Coba lagi nanti.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'operation-not-allowed':
        return 'Operasi tidak diperbolehkan.';
      default:
        return 'Error: ${e.message}';
    }
  }
}
