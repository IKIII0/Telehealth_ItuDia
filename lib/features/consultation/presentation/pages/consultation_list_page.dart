import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/doctor_nav_bar.dart';
import 'package:Telehealth/data/models/consultation_session.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';

/// Daftar konsultasi dokter beserta detail pasien dan keluhannya.
///
/// Dokter dapat memfilter berdasarkan status, membuka sesi untuk berkonsultasi
/// (chat, rekam medis, catatan), atau meninjau sesi yang sudah selesai.
class ConsultationListPage extends StatefulWidget {
  const ConsultationListPage({super.key, this.showNavBar = false});

  final bool showNavBar;

  @override
  State<ConsultationListPage> createState() => _ConsultationListPageState();
}

enum _Filter {
  all('Semua'),
  ongoing('Berlangsung'),
  scheduled('Terjadwal'),
  completed('Selesai');

  const _Filter(this.label);
  final String label;

  bool matches(ConsultationSession s) => switch (this) {
    _Filter.all => true,
    _Filter.ongoing => s.status == ConsultationStatus.ongoing,
    _Filter.scheduled => s.status == ConsultationStatus.scheduled,
    _Filter.completed => s.status == ConsultationStatus.completed,
  };
}

class _ConsultationListPageState extends State<ConsultationListPage> {
  List<ConsultationSession> _sessions = [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_sessions.isEmpty) setState(() => _loading = true);
    try {
      final sessions = await ConsultationRepository.instance.getAllSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat daftar konsultasi: $e';
      });
    }
  }

  Future<void> _open(ConsultationSession s) async {
    await context.pushNamed(
      AppRoutes.doctorConsultationName,
      pathParameters: {'sessionId': s.sessionId},
    );
    // Status dapat berubah (mulai/selesai) selama sesi dibuka.
    if (mounted) await _load();
  }

  int _count(_Filter f) => _sessions.where(f.matches).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _sessions.where(_filter.matches).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: widget.showNavBar
          ? const DoctorNavBar(currentIndex: 1)
          : null,
      appBar: AppBar(
        title: const Text('Daftar Konsultasi'),
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
      body: _buildBody(scheme, visible),
    );
  }

  Widget _buildBody(ColorScheme scheme, List<ConsultationSession> visible) {
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
              Icon(Icons.error_outline, size: 56, color: scheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('consultation_filter_${f.name}'),
                    label: Text('${f.label} (${_count(f)})'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: visible.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Icon(
                        Icons.event_busy_outlined,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Tidak ada konsultasi',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _ConsultationCard(
                      session: visible[i],
                      onOpen: () => _open(visible[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.session, required this.onOpen});

  final ConsultationSession session;
  final VoidCallback onOpen;

  String get _actionLabel => switch (session.status) {
    ConsultationStatus.ongoing => 'Lanjutkan',
    ConsultationStatus.scheduled => 'Mulai',
    ConsultationStatus.requested => 'Tinjau',
    ConsultationStatus.completed => 'Lihat Detail',
    ConsultationStatus.cancelled => 'Lihat Detail',
  };

  IconData get _typeIcon => session.consultationType.contains('Video')
      ? Icons.videocam_outlined
      : Icons.chat_outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = session.status.color;
    final hasAllergy = session.patientAllergies.isNotEmpty;
    final isClosed =
        session.status == ConsultationStatus.completed ||
        session.status == ConsultationStatus.cancelled;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Container(
      key: Key('consultation_card_${session.sessionId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer.withValues(alpha: 0.6),
                child: Icon(Icons.person, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.patientAge} th \u2022 ${session.patientGender}',
                      style: TextStyle(
                        fontSize: 13,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              session.complaint,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF263238),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(_typeIcon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                session.consultationType,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.scheduledTime,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (hasAllergy) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Colors.red.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Alergi: ${session.patientAllergies.join(', ')}',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ],
          if (session.status == ConsultationStatus.completed &&
              session.diagnosisSummary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Diagnosis: ${session.diagnosisSummary}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: isClosed
                ? OutlinedButton(
                    onPressed: onOpen,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: buttonShape,
                    ),
                    child: Text(_actionLabel),
                  )
                : FilledButton(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: buttonShape,
                    ),
                    child: Text(_actionLabel),
                  ),
          ),
        ],
      ),
    );
  }
}
