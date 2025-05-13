import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/pages/auth_service.dart';

class FeedbackService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  Future<void> uploadDetectionImage({
    required String imagePath,
    required Map<String, dynamic> detectionData,
    required String deviceCategory,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await _authService.signInAnonymously();
      }

      final user = FirebaseAuth.instance.currentUser;
      print('👤 Current user: ${user?.uid}');

      final String imageId = DateTime.now().millisecondsSinceEpoch.toString();
      final File imageFile = File(imagePath);
      
      // Upload to Firebase Storage
      final storageRef = _storage.ref()
          .child('detection_feedback')
          .child(deviceCategory)
          .child('$imageId.jpg');
      
      final uploadTask = storageRef.putFile(imageFile);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload to complete and get the final snapshot
      final TaskSnapshot finalSnapshot = await uploadTask;
      print('✅ Upload complete: ${finalSnapshot.bytesTransferred} bytes');

      // Save metadata to Firestore without the URL
      await _firestore.collection('detection_feedback').doc(imageId).set({
        'storagePath': storageRef.fullPath,
        'deviceCategory': deviceCategory,
        'detectionData': detectionData,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user?.uid,
        'fileSize': finalSnapshot.bytesTransferred,
        'uploadStatus': 'complete'
      });
      print('✅ Feedback saved successfully with ID: $imageId');

    } catch (e, stackTrace) {
      print('❌ Error uploading feedback:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}