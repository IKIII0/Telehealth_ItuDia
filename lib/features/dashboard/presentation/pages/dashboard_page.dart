import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // ── Dummy data ──────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _quickActions = [
    {'icon': Icons.medical_services_outlined, 'label': 'Cek\nGejala',   'color': Colors.blue},
    {'icon': Icons.chat_outlined,             'label': 'Chat\nDokter',  'color': Colors.green},
    {'icon': Icons.book_outlined,             'label': 'Jurnal\nKesehatan', 'color': Colors.orange},
    {'icon': Icons.alarm_outlined,            'label': 'Pengingat\nObat', 'color': Colors.purple},
  ];

  static const List<Map<String, dynamic>> _metrics = [
    {'label': 'Tensi', 'value': '120/80', 'unit': 'mmHg', 'icon': Icons.favorite,    'color': Colors.red},
    {'label': 'Detak', 'value': '75',     'unit': 'bpm',  'icon': Icons.monitor_heart,'color': Colors.pink},
    {'label': 'Suhu',  'value': '36.5',   'unit': '°C',   'icon': Icons.thermostat,   'color': Colors.orange},
    {'label': 'Berat', 'value': '65',     'unit': 'kg',   'icon': Icons.scale,        'color': Colors.blue},
  ];

  static const List<Map<String, String>> _schedules = [
    {'doctor': 'Dr. Andi Santoso',  'spec': 'Kardiologi',     'date': '28 Sep 2026', 'time': '09:00'},
    {'doctor': 'Dr. Siti Rahayu',   'spec': 'Penyakit Dalam', 'date': '30 Sep 2026', 'time': '14:30'},
    {'doctor': 'Dr. Budi Prasetyo', 'spec': 'Neurologi',      'date': '02 Okt 2026', 'time': '11:00'},
  ];

  static const List<Map<String, dynamic>> _doctors = [
    {'name': 'Dr. Maya Indah',    'spec': 'Dokter Umum', 'rating': 4.9, 'exp': '10 thn'},
    {'name': 'Dr. Reza Fauzan',   'spec': 'Psikiatri',   'rating': 4.8, 'exp': '8 thn'},
    {'name': 'Dr. Laila Nurfitri','spec': 'Dermatologi', 'rating': 4.7, 'exp': '6 thn'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selamat Datang,',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
            Text('John Doe!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 28),
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
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
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            _buildSectionTitle('Aksi Cepat'),
            _buildQuickActions(),
            const SizedBox(height: 8),
            _buildSectionTitle('Ringkasan Kesehatan'),
            _buildHealthSummary(),
            _buildSectionHeader('Jadwal Mendatang', context),
            _buildScheduleList(),
            _buildSectionHeader('Dokter Rekomendasi', context),
            _buildDoctorList(),
            const SizedBox(height: 24),
          ],
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
        child: const TextField(
          decoration: InputDecoration(
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
                onTap: () {},
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
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(action['icon'] as IconData,
                            color: color, size: 26),
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
  Widget _buildHealthSummary() {
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
                  Icon(Icons.health_and_safety, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Data Terakhir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Spacer(),
                  Text('Hari ini',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(m['icon'] as IconData, color: color, size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m['value'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(m['unit'] as String,
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Text(m['label'] as String,
                            style: const TextStyle(fontSize: 11)),
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
  Widget _buildScheduleList() {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _schedules.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final s = _schedules[i];
          return Container(
            width: 210,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
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
                        s['doctor']!,
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
                Text(s['spec']!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.white70, size: 13),
                    const SizedBox(width: 4),
                    Text(s['date']!,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const Spacer(),
                    const Icon(Icons.access_time,
                        color: Colors.white70, size: 13),
                    const SizedBox(width: 4),
                    Text(s['time']!,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Doctor list ─────────────────────────────────────────────────────────────
  Widget _buildDoctorList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: _doctors.asMap().entries.map((entry) {
            final i   = entry.key;
            final doc = entry.value;
            return Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.person, color: Colors.blue.shade700),
                  ),
                  title: Text(doc['name'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['spec'] as String,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text('${doc['rating']}',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          Text('• ${doc['exp']}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Buat Janji',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
                if (i < _doctors.length - 1)
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
      child: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800)),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800)),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
