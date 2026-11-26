import 'dart:async';

import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/chat_message.dart';
import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/chat_repository.dart';
import 'package:Telehealth/data/repositories/conversation_repository.dart';
import 'package:Telehealth/data/repositories/doctor_repository.dart';

/// Tab Percakapan: dokter berkirim pesan dengan pasien selama sesi.
///
/// Pesan baru hanya bisa dikirim saat sesi berstatus berlangsung. Pada sesi
/// terjadwal atau selesai, riwayat chat tetap tampil tetapi input dinonaktifkan.
class ConsultationChatTab extends StatefulWidget {
  const ConsultationChatTab({super.key, required this.session});

  final ConsultationSession session;

  @override
  State<ConsultationChatTab> createState() => _ConsultationChatTabState();
}

class _ConsultationChatTabState extends State<ConsultationChatTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ConsultationMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _patientTyping = false;
  String? _error;
  StreamSubscription<List<ChatMessage>>? _live;

  /// Id percakapan yang dipakai bersama pasien.
  String _conversationId = '';

  bool get _canSend =>
      widget.session.status == ConsultationStatus.ongoing && !_sending;

  /// Id direktori dokter untuk akun yang sedang login.
  ///
  /// Akun dokter yang baru mendaftar belum punya `directory_doctor_id`, jadi
  /// id direktori mereka adalah `acc_<uid>` (dibuat oleh trigger
  /// 05_doctor_directory_sync.sql). Tanpa fallback ini, sisi dokter dan pasien
  /// memakai id percakapan berbeda.
  Future<String> _resolveDoctorId() async {
    final user = AuthRepository.instance.currentUser;
    final fromProfile = user?.doctorProfile?.doctorId ?? '';
    final fallback = 'acc_${user?.id ?? 'doctor'}';
    if (fromProfile.isEmpty) return fallback;

    final doctor = await DoctorRepository.instance.findById(fromProfile);
    return doctor == null ? fallback : fromProfile;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _live?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = AuthRepository.instance.currentUser;
      final doctorId = await _resolveDoctorId();
      _conversationId = ConversationRepository.pairId(
        doctorId,
        widget.session.patientId,
      );
      await ConversationRepository.instance.ensureForPair(
        doctorId: doctorId,
        doctorName: user?.name ?? 'Dokter',
        doctorInitials: 'DR',
        doctorColor: const Color(0xFF1E88E5),
        patientId: widget.session.patientId,
        doctorOnline: widget.session.status == ConsultationStatus.ongoing,
      );
      final messages = await ChatRepository.instance.fetchMessages(
        _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages.map(_toConsultationMessage).toList();
        _loading = false;
        _error = null;
      });
      _scrollToEnd();
      _listenLive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat percakapan: $e';
      });
    }
  }

  /// Langganan realtime agar pesan pasien masuk tanpa refresh.
  void _listenLive() {
    _live?.cancel();
    _live = ChatRepository.instance.watchMessages(_conversationId).listen((
      messages,
    ) {
      if (!mounted) return;
      setState(() {
        _messages = messages.map(_toConsultationMessage).toList();
        _loading = false;
      });
      _scrollToEnd();
    });
  }

  ConsultationMessage _toConsultationMessage(ChatMessage message) {
    return ConsultationMessage(
      id: message.id,
      sessionId: widget.session.sessionId,
      text: message.text,
      fromDoctor: message.isFromDoctor,
      sentAt: _parseTime(message.time),
    );
  }

  DateTime _parseTime(String value) {
    final parts = value.split(':');
    final now = DateTime.now();
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    }
    return now;
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      // List dibalik (reverse: true), pesan terbaru berada di 0.
      _scrollCtrl.jumpTo(0);
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || !_canSend) return;

    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      final message = await ChatRepository.instance.send(
        _conversationId,
        text,
        sender: 'doctor',
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, _toConsultationMessage(message)];
        _sending = false;
        _patientTyping = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _patientTyping = false;
      });
      _inputCtrl.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pesan gagal terkirim: $e')));
    }
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _inputHint => switch (widget.session.status) {
    ConsultationStatus.requested => 'Terima permintaan untuk membalas',
    ConsultationStatus.ongoing => 'Tulis pesan untuk pasien...',
    ConsultationStatus.scheduled => 'Mulai konsultasi untuk mengirim pesan',
    ConsultationStatus.completed => 'Sesi telah selesai',
    ConsultationStatus.cancelled => 'Sesi dibatalkan',
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada percakapan.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  key: const Key('consultation_chat_list'),
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_patientTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    final hasTyping = _patientTyping;
                    if (hasTyping && i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${widget.session.patientName} sedang mengetik...',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    }
                    final messageIndex =
                        _messages.length - 1 - (i - (hasTyping ? 1 : 0));
                    return _Bubble(
                      message: _messages[messageIndex],
                      time: _formatTime(_messages[messageIndex].sentAt),
                      scheme: scheme,
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('consultation_chat_input'),
                    controller: _inputCtrl,
                    enabled:
                        widget.session.status == ConsultationStatus.ongoing,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _inputHint,
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('consultation_chat_send'),
                  onPressed: _canSend ? _send : null,
                  icon: const Icon(Icons.send_rounded, size: 20),
                  tooltip: 'Kirim',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.time,
    required this.scheme,
  });

  final ConsultationMessage message;
  final String time;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromDoctor;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
          border: mine ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: mine ? scheme.onPrimary : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
