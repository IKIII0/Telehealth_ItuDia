import 'package:flutter/material.dart';

import '../models/conversation.dart';
import 'simulated_api.dart';

/// Repository percakapan (layar Chat) dengan data simulasi.
class ConversationRepository {
  ConversationRepository._();
  static final ConversationRepository instance = ConversationRepository._();

  final List<Conversation> _conversations = [
    const Conversation(
      id: 'conv1',
      name: 'Dr. Ahmad Fauzi',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Baik, jangan lupa minum obat secara teratur ya dan kontrol lagi minggu depan.',
      time: '10:30',
      unreadCount: 2,
      isOnline: true,
      initials: 'AF',
      color: Color(0xFFE53935),
    ),
    const Conversation(
      id: 'conv2',
      name: 'Dr. Siti Rahma',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Hasil lab sudah saya terima, hasilnya normal semua. Tidak perlu khawatir.',
      time: '09:15',
      unreadCount: 0,
      isOnline: true,
      initials: 'SR',
      color: Color(0xFF1E88E5),
    ),
    const Conversation(
      id: 'conv3',
      name: 'Budi (Ayah)',
      role: 'Keluarga',
      type: 'keluarga',
      lastMessage:
          'Sudah ke dokter tadi pagi, katanya harus istirahat total selama 3 hari.',
      time: 'Kemarin',
      unreadCount: 1,
      isOnline: false,
      initials: 'B',
      color: Color(0xFF43A047),
    ),
    const Conversation(
      id: 'conv4',
      name: 'Dr. Dewi Kusuma',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Silakan kirimkan foto kulit yang bermasalah agar saya bisa mengevaluasi.',
      time: 'Kemarin',
      unreadCount: 0,
      isOnline: false,
      initials: 'DK',
      color: Color(0xFF8E24AA),
    ),
    const Conversation(
      id: 'conv5',
      name: 'Rina (Ibu)',
      role: 'Keluarga',
      type: 'keluarga',
      lastMessage:
          'Jangan lupa jadwal kontrol minggu depan ya, sudah saya daftarkan.',
      time: 'Selasa',
      unreadCount: 3,
      isOnline: true,
      initials: 'R',
      color: Color(0xFFFF8F00),
    ),
    const Conversation(
      id: 'conv6',
      name: 'Dr. Rizky Pratama',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Cek gula darah puasa besok pagi ya, lalu kirimkan hasilnya ke saya.',
      time: 'Senin',
      unreadCount: 0,
      isOnline: false,
      initials: 'RP',
      color: Color(0xFF00897B),
    ),
  ];

  Future<List<Conversation>> fetchAll({bool simulateError = false}) {
    return SimulatedApi.run(
      () => List<Conversation>.of(_conversations),
      simulateError: simulateError,
    );
  }

  Future<void> delete(String id) {
    return SimulatedApi.run(
      () => _conversations.removeWhere((c) => c.id == id),
    );
  }
}
