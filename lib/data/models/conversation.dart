import 'package:flutter/material.dart';

/// Model percakapan pada layar Chat.
class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.role,
    required this.type,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    required this.initials,
    required this.color,
  });

  final String id;
  final String name;
  final String role; // 'Dokter' / 'Keluarga'
  final String type; // 'dokter' / 'keluarga'
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final String initials;
  final Color color;
}
