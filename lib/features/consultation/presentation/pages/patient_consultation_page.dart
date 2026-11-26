import 'dart:async';

import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';

/// Daftar konsultasi pasien: permintaan yang dikirim ke dokter beserta
/// statusnya (menunggu, terjadwal, berlangsung, selesai).
class PatientConsultationListPage extends StatefulWidget {
  const PatientConsultationListPage({super.key});

  @override
  State<PatientConsultationListPage> createState() =>
      _PatientConsultationListPageState();
}

class _PatientConsultationListPageState
    extends State<PatientConsultationListPage> {
  bool _loading = true;
  String? _error;
  List<ConsultationSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _sessions.isEmpty;
      _error = null;
    });
    try {
      final sessions = await ConsultationRepository.instance.getMySessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat konsultasi: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Konsultasi Saya'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
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
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.forum_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('Belum ada konsultasi')),
            SizedBox(height: 4),
            Center(
              child: Text(
                'Pilih dokter untuk memulai konsultasi.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: _sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) => _SessionCard(
          session: _sessions[index],
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PatientConsultationRoomPage(
                  sessionId: _sessions[index].sessionId,
                ),
              ),
            );
            if (mounted) await _load();
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final ConsultationSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = session.status.color;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.doctorName.isEmpty
                              ? 'Dokter'
                              : session.doctorName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.doctorSpecialization.isEmpty
                              ? session.consultationType
                              : session.doctorSpecialization,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      session.status.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                session.complaint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      session.scheduledTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Text(
                    'Buka',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: scheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halaman chat/status satu sesi konsultasi dari sisi pasien.
class PatientConsultationRoomPage extends StatefulWidget {
  const PatientConsultationRoomPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<PatientConsultationRoomPage> createState() =>
      _PatientConsultationRoomPageState();
}

class _PatientConsultationRoomPageState
    extends State<PatientConsultationRoomPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  ConsultationSession? _session;
  List<ConsultationMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await ConsultationRepository.instance.getSession(
        widget.sessionId,
      );
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _error = 'Sesi konsultasi tidak ditemukan.';
          _loading = false;
        });
        return;
      }
      final messages = await ConsultationRepository.instance.getMessages(
        widget.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
      _syncPolling(session.status);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat sesi: $error';
        _loading = false;
      });
    }
  }

  /// Polling ringan agar balasan dokter muncul tanpa menekan refresh.
  void _syncPolling(ConsultationStatus status) {
    final shouldPoll =
        status == ConsultationStatus.ongoing ||
        status == ConsultationStatus.scheduled ||
        status == ConsultationStatus.requested;
    if (!shouldPoll) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ConsultationRepository.instance.sendPatientMessage(
        widget.sessionId,
        text,
      );
      _inputCtrl.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesan gagal dikirim: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan permintaan?'),
        content: const Text(
          'Permintaan konsultasi ini akan dibatalkan dan tidak diproses dokter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ConsultationRepository.instance.cancelRequest(widget.sessionId);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = _session;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session?.doctorName.isNotEmpty == true
                  ? session!.doctorName
                  : 'Konsultasi',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (session != null)
              Text(
                session.status.label,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final session = _session;
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text(_error ?? 'Sesi tidak ditemukan.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final canChat = session.status == ConsultationStatus.ongoing;

    return Column(
      children: [
        _StatusBanner(session: session, onCancel: _cancel),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      session.status == ConsultationStatus.requested
                          ? 'Permintaan Anda sedang menunggu konfirmasi dokter.'
                          : 'Belum ada pesan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _messages.length,
                  itemBuilder: (_, index) {
                    final message = _messages[index];
                    return _MessageBubble(message: message, scheme: scheme);
                  },
                ),
        ),
        if (canChat) _buildComposer(scheme),
      ],
    );
  }

  Widget _buildComposer(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('patient_chat_field'),
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan untuk dokter...',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.session, required this.onCancel});

  final ConsultationSession session;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = session.status.color;

    final (icon, message) = switch (session.status) {
      ConsultationStatus.requested => (
        Icons.hourglass_top,
        'Menunggu dokter menerima permintaan Anda.',
      ),
      ConsultationStatus.scheduled => (
        Icons.event_available,
        'Diterima dokter. Sesi dijadwalkan ${session.scheduledTime}.',
      ),
      ConsultationStatus.ongoing => (
        Icons.forum_rounded,
        'Sesi berlangsung. Anda dapat mengirim pesan.',
      ),
      ConsultationStatus.completed => (Icons.check_circle, 'Sesi selesai.'),
      ConsultationStatus.cancelled => (
        Icons.cancel_outlined,
        'Sesi dibatalkan.',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          if (session.status == ConsultationStatus.requested) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: Text(
                  'Batalkan permintaan',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
          ],
          if (session.status == ConsultationStatus.completed &&
              session.diagnosisSummary.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Diagnosis dokter',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.diagnosisSummary,
              style: const TextStyle(fontSize: 13),
            ),
            if (session.doctorNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                session.doctorNotes,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.scheme});

  final ConsultationMessage message;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final fromDoctor = message.fromDoctor;
    final align = fromDoctor ? Alignment.centerLeft : Alignment.centerRight;
    final color = fromDoctor ? Colors.white : scheme.primary;
    final textColor = fromDoctor ? Colors.black87 : Colors.white;

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromDoctor ? 4 : 16),
            bottomRight: Radius.circular(fromDoctor ? 16 : 4),
          ),
          border: fromDoctor
              ? Border.all(color: const Color(0xFFE5E7EB))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.sentAt.hour.toString().padLeft(2, '0')}:'
              '${message.sentAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
