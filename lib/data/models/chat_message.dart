/// Arah pengirim pesan chat.
enum ChatSender { patient, doctor }

/// Satu pesan di dalam ruang percakapan.
///
/// `conversationId` adalah relasi ke [Conversation]. Arah pesan disimpan di
/// [sender] supaya percakapan bisa dibaca dari sisi pasien maupun dokter.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.time,
    this.sender = ChatSender.patient,
  });

  final String id;
  final String conversationId;
  final String text;
  final ChatSender sender;

  /// Jam kirim, mis. "10:30".
  final String time;

  bool get isFromDoctor => sender == ChatSender.doctor;

  /// Kompatibilitas tampilan lama: dari sudut pandang pasien.
  bool get isMe => sender == ChatSender.patient;

  String get senderValue => sender == ChatSender.doctor ? 'doctor' : 'patient';

  static ChatSender parseSender(String? value, {bool fallbackIsMe = false}) {
    if (value == 'doctor') return ChatSender.doctor;
    if (value == 'patient') return ChatSender.patient;
    return fallbackIsMe ? ChatSender.patient : ChatSender.doctor;
  }
}
