import 'package:flutter/material.dart';

import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/appointment.dart';
import 'package:Telehealth/data/models/doctor.dart';
import 'package:Telehealth/data/repositories/doctor_repository.dart';
import 'package:Telehealth/lib/features/profile/presentation/pages/profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ── Static local data ───────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _quickActions = [
    {
      'icon': Icons.medical_services_outlined,
      'label': 'Cek\nGejala',
      'color': Colors.blue,
      'route': '/symptom-checker',
    },
    {
      'icon': Icons.chat_outlined,
      'label': 'Chat\nDokter',
      'color': Colors.green,
      'route': '/chat',
    },
    {
      'icon': Icons.book_outlined,
      'label': 'Jurnal\nKesehatan',
      'color': Colors.orange,
      'route': '/journal',
    },
    {
      'icon': Icons.alarm_outlined,
      'label': 'Pengingat\nObat',
      'color': Colors.purple,
      'route': '/medication',
    },
  ];

  static const List<Map<String, dynamic>> _metrics = [
    {
      'label': 'Tensi',
      'value': '120/80',
      'unit': 'mmHg',
      'icon': Icons.favorite,
      'color': Colors.red,
    },
    {
      'label': 'Detak',
      'value': '75',
      'unit': 'bpm',
      'icon': Icons.monitor_heart,
      'color': Colors.pink,
    },
    {
      'label': 'Suhu',
      'value': '36.5',
      'unit': '°C',
      'icon': Icons.thermostat,
      'color': Colors.orange,
    },
    {
      'label': 'Berat',
      'value': '65',
      'unit': 'kg',
      'icon': Icons.scale,
      'color': Colors.blue,
    },
  ];

  /// Jadwal konsultasi contoh (data lokal). `doctorId` menghubungkan ke [Doctor].
  static const List<Appointment> _appointments = [
    Appointment(
      id: 'apt1',
      doctorId: 'doc1',
      doctorName: 'Dr. Rifki Al Sauqy, Sp.JP',
      specialization: 'Spesialis Jantung',
      date: '28 Sep 2026',
      time: '09:00',
    ),
    Appointment(
      id: 'apt2',
      doctorId: 'doc2',
      doctorName: 'Dr. Yehezkiel Sitanggang, Sp.A',
      specialization: 'Spesialis Anak',
      date: '30 Sep 2026',
      time: '14:30',
    ),
    Appointment(
      id: 'apt3',
      doctorId: 'doc5',
      doctorName: 'Dr. Farhan Prasetyo, Sp.PD',
      specialization: 'Spesialis Penyakit Dalam',
      date: '02 Okt 2026',
      time: '11:00',
    ),
  ];

  // ── Async state ─────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  List<Doctor> _recommended = const [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctors = await DoctorRepository.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _recommended = doctors.take(3).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _go(String route) => Navigator.pushNamed(context, route);

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat Datang,',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            Text(
              'ItuDia!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 28),
                onPressed: () =>
                    showAppSnack(context, 'Tidak ada notifikasi baru'),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 20),
              onTap: () => _go('/profile'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecommendations,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              _buildSectionTitle('Aksi Cepat'),
              _buildQuickActions(),
              const SizedBox(height: 8),
              _buildSectionTitle('Ringkasan Kesehatan'),
              _buildHealthSummary(scheme),
              _buildSectionHeader('Jadwal Mendatang'),
              _buildScheduleList(scheme),
              _buildSectionHeader('Dokter Rekomendasi'),
              _buildRecommendations(scheme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: TextField(
          readOnly: true,
          onTap: () => _go('/doctors'),
          decoration: const InputDecoration(
            hintText: 'Cari dokter, gejala, obat...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Quick actions ───────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: _quickActions.map((action) {
          final color = action['color'] as Color;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _go(action['route'] as String),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Health summary ──────────────────────────────────────────────────────────
  Widget _buildHealthSummary(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.health_and_safety, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Data Terakhir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Hari ini',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: _metrics.map((m) {
                  final color = m['color'] as Color;
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            m['icon'] as IconData,
                            color: color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m['value'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          m['unit'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m['label'] as String,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Schedule list ───────────────────────────────────────────────────────────
  Widget _buildScheduleList(ColorScheme scheme) {
    final gradientEnd = Color.lerp(scheme.primary, Colors.white, 0.35)!;
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _appointments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final appointment = _appointments[i];
          return Container(
            width: 210,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, gradientEnd]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.doctorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  appointment.specialization,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.date,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.access_time,
                      color: Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.time,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Recommended doctors ─────────────────────────────────────────────────────
  Widget _buildRecommendations(ColorScheme scheme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: LoadingView(message: 'Memuat dokter rekomendasi...'),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ErrorView(message: _error!, onRetry: _loadRecommendations),
      );
    }
    if (_recommended.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: EmptyView(
          icon: Icons.medical_services_outlined,
          title: 'Belum Ada Dokter',
          message: 'Daftar dokter rekomendasi masih kosong.',
          actionLabel: 'Muat Ulang',
          onAction: _loadRecommendations,
        ),
      );
    }
    return _buildDoctorList(scheme);
  }

  Widget _buildDoctorList(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: _recommended.asMap().entries.map((entry) {
            final i = entry.key;
            final doc = entry.value;
            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      doc.initials,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    doc.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.specialization,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${doc.rating}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${doc.experience} thn',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () => _go('/doctors'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Buat Janji',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                if (i < _recommended.length - 1)
                  const Divider(height: 1, indent: 72),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _go('/doctors'),
            child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
