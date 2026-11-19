import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../models/chat_message.dart';
import 'simulated_api.dart';
import 'supabase_mappers.dart';

/// Repository pesan chat.
///
/// Memakai tabel `chat_messages` di Supabase bila tersedia, selain itu
/// memakai data simulasi lokal (seed di bawah).
class ChatRepository {
  ChatRepository._() {
    _seed();
  }

  static final ChatRepository instance = ChatRepository._();

  SupabaseClient? get _db => SupabaseConfig.client;

  int _idCounter = 0;

  final Map<String, List<ChatMessage>> _store = {};

  String _nextId() {
    _idCounter++;
    return 'msg_$_idCounter';
  }

  void _add(String conversationId, String text, bool isMe, String time) {
    _store
        .putIfAbsent(conversationId, () => <ChatMessage>[])
        .add(
          ChatMessage(
            id: _nextId(),
            conversationId: conversationId,
            text: text,
            sender: isMe ? ChatSender.patient : ChatSender.doctor,
            time: time,
          ),
        );
  }

  void _seed() {
    // ── Dokter ───────────────────────────────────────────────────────────────
    _add('conv1', 'Selamat pagi, ada yang bisa saya bantu?', false, '10:12');
    _add(
      'conv1',
      'Pagi Dok. Kemarin tensi saya 140/90, apakah berbahaya?',
      true,
      '10:15',
    );
    _add(
      'conv1',
      'Masih bisa dikendalikan. Istirahat cukup dan kurangi garam ya.',
      false,
      '10:20',
    );
    _add(
      'conv1',
      'Baik, jangan lupa minum obat secara teratur ya dan kontrol lagi minggu depan.',
      false,
      '10:30',
    );

    _add(
      'conv2',
      'Selamat pagi, hasil laboratorium Anda sudah saya terima.',
      false,
      '09:02',
    );
    _add('conv2', 'Bagaimana hasilnya Dok?', true, '09:10');
    _add(
      'conv2',
      'Hasil lab sudah saya terima, hasilnya normal semua. Tidak perlu khawatir.',
      false,
      '09:15',
    );

    _add(
      'conv3',
      'Sudah ke dokter tadi pagi, katanya harus istirahat total 3 hari.',
      false,
      '08:40',
    );
    _add('conv3', 'Baik Yah, nanti sore aku jenguk ya.', true, '08:45');
    _add(
      'conv3',
      'Sudah ke dokter tadi pagi, katanya harus istirahat total selama 3 hari.',
      false,
      'Kemarin',
    );

    _add(
      'conv4',
      'Silakan kirimkan foto kulit yang bermasalah agar saya bisa mengevaluasi.',
      false,
      'Kemarin',
    );

    _add('conv5', 'Nak, jangan lupa makan siang ya.', false, '12:05');
    _add('conv5', 'Iya Bu, sudah kok.', true, '12:20');
    _add(
      'conv5',
      'Jangan lupa jadwal kontrol minggu depan ya, sudah saya daftarkan.',
      false,
      'Selasa',
    );

    _add(
      'conv6',
      'Cek gula darah puasa besok pagi ya, lalu kirimkan hasilnya ke saya.',
      false,
      'Senin',
    );
  }

  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    bool simulateError = false,
  }) async {
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(
        () => List<ChatMessage>.of(
          _store[conversationId] ?? const <ChatMessage>[],
        ),
        simulateError: simulateError,
      );
    }

    final rows = await db
        .from('chat_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return rows.map(chatMessageFromRow).toList();
  }

  /// Menyimpan pesan baru. [sender] menentukan arah pesan
  /// (`'patient'` atau `'doctor'`).
  Future<ChatMessage> send(
    String conversationId,
    String text, {
    String sender = 'patient',
  }) async {
    final time = _now();
    final direction = ChatMessage.parseSender(sender);
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        final message = ChatMessage(
          id: _nextId(),
          conversationId: conversationId,
          text: text,
          sender: direction,
          time: time,
        );
        _store.putIfAbsent(conversationId, () => <ChatMessage>[]).add(message);
        return message;
      });
    }

    final row = await db
        .from('chat_messages')
        .insert({
          'conversation_id': conversationId,
          'body': text,
          'sender': direction.name,
          'is_me': direction == ChatSender.patient,
          'time_label': time,
        })
        .select()
        .single();

    // Jaga ringkasan daftar percakapan tetap terbaru.
    try {
      await db
          .from('conversations')
          .update({'last_message': text, 'time_label': time})
          .eq('id', conversationId);
    } catch (_) {
      // Ringkasan gagal diperbarui tidak menghalangi pengiriman pesan.
    }

    return chatMessageFromRow(row);
  }

  /// Balasan otomatis dari lawan bicara (untuk keperluan demo).
  ///
  /// [text] bisa diisi untuk pesan pembuka sesi konsultasi.
  Future<ChatMessage> autoReply(String conversationId, {String? text}) async {
    final body = text ?? _cannedReply(conversationId);
    final time = _now();
    final db = _db;
    if (db == null) {
      return SimulatedApi.run(() {
        final message = ChatMessage(
          id: _nextId(),
          conversationId: conversationId,
          text: body,
          sender: ChatSender.doctor,
          time: time,
        );
        _store.putIfAbsent(conversationId, () => <ChatMessage>[]).add(message);
        return message;
      });
    }

    final row = await db
        .from('chat_messages')
        .insert({
          'conversation_id': conversationId,
          'body': body,
          'sender': 'doctor',
          'is_me': false,
          'time_label': time,
        })
        .select()
        .single();
    return chatMessageFromRow(row);
  }

  /// Stream pesan realtime untuk [conversationId].
  ///
  /// Memakai Supabase Realtime (tabel `chat_messages`). Bila Supabase tidak
  /// aktif, stream kosong — UI tetap menampilkan pesan hasil kirim manual.
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    final db = _db;
    if (db == null) return const Stream.empty();

    late final StreamController<List<ChatMessage>> controller;
    RealtimeChannel? channel;

    Future<void> emitAll() async {
      try {
        final rows = await db
            .from('chat_messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at');
        if (!controller.isClosed) {
          controller.add(rows.map(chatMessageFromRow).toList());
        }
      } catch (_) {
        // Biarkan data lama tetap tampil.
      }
    }

    controller = StreamController<List<ChatMessage>>(
      onListen: () {
        channel = db
            .channel('chat_$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'chat_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (_) => emitAll(),
            )
            .subscribe();
        emitAll();
      },
      onCancel: () async {
        final active = channel;
        channel = null;
        if (active != null) await db.removeChannel(active);
      },
    );

    return controller.stream;
  }

  String _cannedReply(String conversationId) {
    switch (conversationId) {
      case 'conv1':
        return 'Baik, saya catat ya. Jangan lupa istirahat cukup.';
      case 'conv2':
        return 'Siap, nanti saya periksa kembali hasilnya.';
      case 'conv3':
        return 'Iya, hati-hati di jalan ya.';
      case 'conv4':
        return 'Terima kasih, fotonya sudah saya terima.';
      case 'conv5':
        return 'Alhamdulillah, jaga kesehatan ya Nak.';
      case 'conv6':
        return 'Baik, saya tunggu hasilnya ya.';
      default:
        return 'Baik, terima kasih atas informasinya.';
    }
  }

  String _now() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
