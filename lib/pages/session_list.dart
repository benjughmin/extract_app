// Displays a list of saved sessions with options to view details or delete them.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'session.dart';
import 'session_repository.dart';
import 'base.dart';
import 'assistant.dart';

class SessionsListPage extends StatefulWidget {
  const SessionsListPage({super.key});

  @override
  State<SessionsListPage> createState() => _SessionsListPageState();
}

class _SessionsListPageState extends State<SessionsListPage> {
  final SessionRepository _repository = SessionRepository();
  late Future<List<SavedSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _repository.getSavedSessions();
  }

  void _refreshSessions() {
    setState(() {
      _sessionsFuture = _repository.getSavedSessions();
    });
  }

  String _formatDate(DateTime date) {
    return timeago.format(date, locale: 'en');
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      title: 'Saved Sessions',
      child: FutureBuilder<List<SavedSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No saved sessions yet',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final sessions = snapshot.data!;
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: session.mainImagePath != null
                      ? Image.file(File(session.mainImagePath!), width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.devices, size: 40),
                  title: Text(
                    session.deviceCategory,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.detectedComponents.length} components',
                        style: GoogleFonts.montserrat(),
                      ),
                      Text(
                        _formatDate(session.savedAt),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await _repository.deleteSession(session.id);
                      _refreshSessions();
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatbotRedo(
                          initialCategory: session.deviceCategory,
                          initialImagePath: session.mainImagePath,
                          initialDetections: session.detectedComponents,
                          initialComponentImages: session.componentImages,
                          initialBatch: [session.id],
                        ),
                      ),
                    ).then((_) {
                      _refreshSessions();
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}