import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      print('✅ Anonymous auth successful. UID: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      print('❌ Anonymous auth failed: $e');
      return null;
    }
  }
}