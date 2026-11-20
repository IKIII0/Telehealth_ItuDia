import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/core/widgets/role_badge.dart';
import 'package:Telehealth/data/models/doctor.dart';
import 'package:Telehealth/data/repositories/doctor_repository.dart';

/// Halaman detail dokter.
///
/// Route hanya membawa `doctorId`; data dokter dimuat dari
/// [DoctorRepository] agar objek model tidak disimpan di URL.
class DoctorDetailPage extends StatefulWidget {
  const DoctorDetailPage({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  bool _loading = true;
  String? _error;
  Doctor? _doctor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctor = await DoctorRepository.instance.findById(widget.doctorId);
      if (!mounted) return;
      setState(() {
        _doctor = doctor;
        _loading = false;
        if (doctor == null) {
          _error = 'Dokter tidak ditemukan.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doctor = _doctor;
    if (doctor != null) {
      return _DoctorDetailContent(doctor: doctor);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Detail Dokter'),
      ),
      body: _loading
          ? const LoadingView(message: 'Memuat data dokter...')
          : ErrorView(
              message: _error ?? 'Dokter tidak ditemukan.',
              onRetry: _load,
            ),
    );
  }
}

class _DoctorDetailContent extends StatelessWidget {
  final Doctor doctor;

  const _DoctorDetailContent({required this.doctor});

  // ── helpers ────────────────────────────────────────────────────────────────

  String _formatPrice(int price) {
    final str = price.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }

  // ── konsultasi ──���─────────────────────────────────────────────────────────

  void _startConsultation(BuildContext context) {
    context.pushNamed(
      AppRoutes.patientConsultationName,
      pathParameters: {'doctorId': doctor.id},
      extra: doctor,
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final int consultPrice = doctor.price;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            backgroundColor: scheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              const RoleBadge.patient(),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: scheme.primary,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Image.asset(
                              RoleBadge.doctorIcon,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          doctor.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.specialization,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (doctor.rating > 0) ...[
                            _HeaderChip(
                              icon: Icons.star_rounded,
                              label: doctor.rating.toStringAsFixed(1),
                              iconColor: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                          ],
                          _HeaderChip(
                            icon: Icons.circle,
                            label: doctor.available
                                ? 'Tersedia hari ini'
                                : 'Belum tersedia',
                            iconColor: doctor.available
                                ? Colors.greenAccent
                                : Colors.white54,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Stats Card
                _buildStatsCard(scheme.primary),

                // About Dokter
                _SectionTitle(title: 'Tentang dokter'),
                _buildAboutCard(context),

                // Jadwal Praktik
                _SectionTitle(title: 'Jadwal praktik'),
                _buildScheduleRow(),

                // Layanan & Harga
                _SectionTitle(title: 'Layanan & harga'),
                _buildServicesCard(context, consultPrice),

                // Ulasan Pasien
                _SectionTitle(title: 'Ulasan pasien'),
                ..._buildReviewCards(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky Bottom Bar ────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(
        context,
        scheme.primary,
        consultPrice,
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _buildStatsCard(Color accentColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
              value: doctor.rating.toStringAsFixed(1),
              label: 'Rating',
            ),
          ),
          const _VertDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.work_outline_rounded,
              iconColor: accentColor,
              value: '${doctor.experience} th',
              label: 'Pengalaman',
            ),
          ),
          const _VertDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.people_outline_rounded,
              iconColor: accentColor,
              value: '1.2K',
              label: 'Pasien',
            ),
          ),
          const _VertDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.bolt_rounded,
              iconColor: accentColor,
              value: '98%',
              label: 'Respons',
            ),
          ),
        ],
      ),
    );
  }

  // ── About Card ─────────────────────────────────────────────────────────────

  Widget _buildAboutCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doctor.bio,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.local_hospital_rounded,
            color: Theme.of(context).colorScheme.primary,
            label: 'Rumah Sakit',
            value: doctor.hospital,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.school_rounded,
            color: Theme.of(context).colorScheme.primary,
            label: 'Pendidikan',
            value: doctor.education,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.verified_outlined,
            color: Theme.of(context).colorScheme.primary,
            label: 'No. STR',
            value: 'STR-2024-${doctor.experience * 1357}',
          ),
        ],
      ),
    );
  }

  // ── Schedule Row ───────────────────────────────────────────────────────────

  Widget _buildScheduleRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: const [
          _ScheduleCard(day: 'Sen', hours: '08:00\n12:00', active: true),
          _ScheduleCard(day: 'Sel', hours: '13:00\n17:00', active: true),
          _ScheduleCard(day: 'Rab', hours: '08:00\n12:00', active: true),
          _ScheduleCard(day: 'Kam', hours: 'Libur', active: false),
          _ScheduleCard(day: 'Jum', hours: '08:00\n11:00', active: true),
          _ScheduleCard(day: 'Sab', hours: '09:00\n13:00', active: true),
          _ScheduleCard(day: 'Min', hours: 'Libur', active: false),
        ],
      ),
    );
  }

  // ── Services Card ──────────────────────────────────────────────────────────

  Widget _buildServicesCard(BuildContext context, int basePrice) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _ServiceTile(
            icon: Icons.video_call_rounded,
            color: scheme.primary,
            title: 'Konsultasi Online',
            subtitle: 'Chat & video call dengan dokter',
            price: basePrice,
            formatPrice: _formatPrice,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _ServiceTile(
            icon: Icons.local_hospital_rounded,
            color: scheme.primary,
            title: 'Tatap Muka',
            subtitle: 'Kunjungi dokter langsung di klinik',
            price: (basePrice * 1.5).toInt(),
            formatPrice: _formatPrice,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _ServiceTile(
            icon: Icons.home_rounded,
            color: scheme.primary,
            title: 'Home Visit',
            subtitle: 'Dokter datang ke rumah Anda',
            price: (basePrice * 2.5).toInt(),
            formatPrice: _formatPrice,
          ),
        ],
      ),
    );
  }

  // ── Review Cards ───────────────────────────────────────────────────────────

  List<Widget> _buildReviewCards() {
    const reviews = [
      {
        'name': 'Andi Wijaya',
        'rating': 5,
        'comment':
            'Dokternya sangat ramah dan penjelasannya detail sekali. Saya merasa nyaman berkonsultasi dan masalah saya terselesaikan!',
        'date': '20 Sep 2024',
        'initials': 'AW',
        'colorVal': 0xFF6B7280,
      },
      {
        'name': 'Rina Sari',
        'rating': 5,
        'comment':
            'Responsif dan profesional. Dokter langsung mengerti keluhan saya dan memberikan solusi yang tepat.',
        'date': '15 Sep 2024',
        'initials': 'RS',
        'colorVal': 0xFFD81B60,
      },
      {
        'name': 'Doni Pratama',
        'rating': 4,
        'comment':
            'Dokter yang baik, penjelasan mudah dipahami. Antrian agak lama tapi pelayanannya memuaskan.',
        'date': '10 Sep 2024',
        'initials': 'DP',
        'colorVal': 0xFF00897B,
      },
    ];

    return reviews.map((review) {
      final color = Color(review['colorVal'] as int);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    review['initials'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < (review['rating'] as int)
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Text(
                  review['date'] as String,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review['comment'] as String,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, Color accentColor, int price) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mulai dari',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${_formatPrice(price)}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.goNamed(AppRoutes.patientChatName),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: accentColor,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _startConsultation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Konsultasi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade900,
        ),
      ),
    );
  }
}

/// Chip kecil pada header profil dokter (rating & status ketersediaan).
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: Colors.grey.shade200);
  }
}

class _ScheduleCard extends StatelessWidget {
  final String day;
  final String hours;
  final bool active;

  const _ScheduleCard({
    required this.day,
    required this.hours,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: active ? scheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? scheme.primary : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: active ? Colors.white : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hours,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: active
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int price;
  final String Function(int) formatPrice;

  const _ServiceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
      ),
      trailing: Text(
        'Rp ${formatPrice(price)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
