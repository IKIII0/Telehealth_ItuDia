import 'package:Telehealth/data/models/chat_message.dart';
import 'package:Telehealth/data/repositories/simulated_api.dart';

/// Repository pesan chat dengan data simulasi.
///
/// Pesan disimpan per `conversationId` di memori, sehingga percakapan
/// bertahan selama sesi aplikasi berjalan.
class ChatRepository {
  ChatRepository._() {
    _seed();
  }

  static final ChatRepository instance = ChatRepository._();

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
            isMe: isMe,
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
  }) {
    return SimulatedApi.run(
      () =>
          List<ChatMessage>.of(_store[conversationId] ?? const <ChatMessage>[]),
      simulateError: simulateError,
    );
  }

  /// Menyimpan pesan yang dikirim pengguna.
  Future<ChatMessage> send(String conversationId, String text) {
    return SimulatedApi.run(() {
      final message = ChatMessage(
        id: _nextId(),
        conversationId: conversationId,
        text: text,
        isMe: true,
        time: _now(),
      );
      _store.putIfAbsent(conversationId, () => <ChatMessage>[]).add(message);
      return message;
    });
  }

  /// Balasan otomatis dari lawan bicara (untuk keperluan demo).
  Future<ChatMessage> autoReply(String conversationId) {
    return SimulatedApi.run(() {
      final message = ChatMessage(
        id: _nextId(),
        conversationId: conversationId,
        text: _cannedReply(conversationId),
        isMe: false,
        time: _now(),
      );
      _store.putIfAbsent(conversationId, () => <ChatMessage>[]).add(message);
      return message;
    });
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
