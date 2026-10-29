import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/conversation.dart';
import 'simulated_api.dart';
import 'supabase_mappers.dart';

/// Repository percakapan (layar Chat).
///
/// Memakai tabel `conversations` di Supabase bila tersedia, selain itu
/// memakai data simulasi lokal.
class ConversationRepository {
  ConversationRepository._();
  static final ConversationRepository instance = ConversationRepository._();

  SupabaseClient? get _db => SupabaseConfig.client;

  final List<Conversation> _conversations = [
    const Conversation(
      id: 'conv1',
      name: 'dr. Rifki Al Sauqy, Sp.JP',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Baik, jangan lupa minum obat secara teratur ya dan kontrol lagi minggu depan.',
      time: '10:30',
      unreadCount: 2,
      isOnline: true,
      initials: 'RAS',
      color: Color(0xFFE53935),
    ),
    const Conversation(
      id: 'conv2',
      name: 'dr. Yehezkiel Sitanggang, Sp.A',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Hasil lab sudah saya terima, hasilnya normal semua. Tidak perlu khawatir.',
      time: '09:15',
      unreadCount: 0,
      isOnline: true,
      initials: 'YS',
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
      name: 'dr. Pocut Qanitah, Sp.KK',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Silakan kirimkan foto kulit yang bermasalah agar saya bisa mengevaluasi.',
      time: 'Kemarin',
      unreadCount: 0,
      isOnline: false,
      initials: 'PQ',
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
      name: 'dr. Daffa Afdhillah, Sp.PD',
      role: 'Dokter',
      type: 'dokter',
      lastMessage:
          'Cek gula darah puasa besok pagi ya, lalu kirimkan hasilnya ke saya.',
      time: 'Senin',
      unreadCount: 0,
      isOnline: false,
      initials: 'DA',
      color: Color(0xFF00897B),
    ),
  ];

  Future<List<Conversation>> fetchAll({bool simulateError = false}) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () => List<Conversation>.of(_conversations),
        simulateError: simulateError,
      );
    }

    final rows = await db.from('conversations').select().order('created_at');
    return rows.map(conversationFromRow).toList();
  }

  Future<Conversation?> findById(String id) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        final matches = _conversations.where((c) => c.id == id);
        return matches.isEmpty ? null : matches.first;
      });
    }

    final row = await db
        .from('conversations')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : conversationFromRow(row);
  }

  Future<void> delete(String id) async {
    final db = _db;
    if (db == null) {
      await SimulatedApi.run(
        () => _conversations.removeWhere((c) => c.id == id),
      );
      return;
    }

    // Pesan ikut terhapus lewat ON DELETE CASCADE.
    await db.from('conversations').delete().eq('id', id);
  }
}
