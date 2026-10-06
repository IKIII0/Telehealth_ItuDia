/// Satu pesan di dalam ruang percakapan.
///
/// `conversationId` adalah relasi ke [Conversation].
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.isMe,
    required this.time,
  });

  final String id;
  final String conversationId;
  final String text;

  /// `true` bila pesan dikirim oleh pengguna (bukan lawan bicara).
  final bool isMe;

  /// Jam kirim, mis. "10:30".
  final String time;
}
