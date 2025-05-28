// Handles the storage and retrieval of saved sessions using Flutter Secure Storage.
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session.dart';

class SessionRepository {
  static const _storage = FlutterSecureStorage(); // Securely stores session data locally on the device. 
  static const _sessionsKey = 'saved_sessions';

  Future<List<SavedSession>> getSavedSessions() async {
    final jsonString = await _storage.read(key: _sessionsKey);
    if (jsonString == null) return [];
    
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => SavedSession.fromJson(json)).toList();
  }

  Future<void> saveSession(SavedSession session) async {
    final sessions = await getSavedSessions();
    sessions.add(session);
    
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _storage.write(key: _sessionsKey, value: json.encode(jsonList));
  }

  Future<void> deleteSession(String id) async {
    final sessions = await getSavedSessions();
    sessions.removeWhere((session) => session.id == id);
    
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _storage.write(key: _sessionsKey, value: json.encode(jsonList));
  }


  Future<void> saveAllSessions(List<Map<String, dynamic>> sessions) async {
    await _storage.write(
      key: _sessionsKey,
      value: json.encode(sessions),
    );
  }
}