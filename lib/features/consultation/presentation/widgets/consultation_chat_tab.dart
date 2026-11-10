import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';

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

  bool get _canSend =>
      widget.session.status == ConsultationStatus.ongoing && !_sending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await ConsultationRepository.instance.getMessages(
        widget.session.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat percakapan: $e';
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || !_canSend) return;

    final sessionId = widget.session.sessionId;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      final message = await ConsultationRepository.instance.sendDoctorMessage(
        sessionId,
        text,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _sending = false;
        _patientTyping = true;
      });
      _scrollToEnd();

      final reply = await ConsultationRepository.instance.simulatePatientReply(
        sessionId,
      );
      if (!mounted) return;
      setState(() {
        if (reply != null) _messages = [..._messages, reply];
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
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_patientTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _messages.length) {
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
                    return _Bubble(
                      message: _messages[i],
                      time: _formatTime(_messages[i].sentAt),
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
