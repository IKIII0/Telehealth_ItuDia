import 'package:flutter/material.dart';

class DoctorDetailPage extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const DoctorDetailPage({super.key, required this.doctor});

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

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
        doctor['avatarColor'] as Color? ?? const Color(0xFF2196F3);
    final int consultPrice = doctor['price'] as int? ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: accentColor,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon:
                    const Icon(Icons.bookmark_border, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        child: const Icon(Icons.person,
                            size: 54, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        doctor['name'] as String? ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor['specialization'] as String? ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
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
                _buildStatsCard(accentColor),

                // About Dokter
                _SectionTitle(title: 'Tentang Dokter'),
                _buildAboutCard(),

                // Jadwal Praktik
                _SectionTitle(title: 'Jadwal Praktik'),
                _buildScheduleRow(),

                // Layanan & Harga
                _SectionTitle(title: 'Layanan & Harga'),
                _buildServicesCard(consultPrice),

                // Ulasan Pasien
                _SectionTitle(title: 'Ulasan Pasien'),
                ..._buildReviewCards(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky Bottom Bar ────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(accentColor, consultPrice),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _buildStatsCard(Color accentColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            value: (doctor['rating'] as double? ?? 0.0).toStringAsFixed(1),
            label: 'Rating',
          ),
          _VertDivider(),
          _StatItem(
            icon: Icons.work_rounded,
            iconColor: accentColor,
            value: '${doctor['experience'] ?? 0} Thn',
            label: 'Pengalaman',
          ),
          _VertDivider(),
          _StatItem(
            icon: Icons.people_alt_rounded,
            iconColor: Colors.green,
            value: '1.2K+',
            label: 'Pasien',
          ),
          _VertDivider(),
          _StatItem(
            icon: Icons.chat_bubble_rounded,
            iconColor: Colors.purple,
            value: '98%',
            label: 'Respons',
          ),
        ],
      ),
    );
  }

  // ── About Card ─────────────────────────────────────────────────────────────

  Widget _buildAboutCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doctor['bio'] as String? ??
                'Dokter berpengalaman dan terpercaya.',
            style: const TextStyle(
                fontSize: 14, height: 1.65, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.local_hospital_rounded,
            color: Colors.red[400]!,
            label: 'Rumah Sakit',
            value: doctor['hospital'] as String? ?? '-',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.school_rounded,
            color: Colors.blue[400]!,
            label: 'Pendidikan',
            value: doctor['education'] as String? ?? '-',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.verified_rounded,
            color: Colors.green[400]!,
            label: 'No. STR',
            value:
                'STR-2024-${((doctor['experience'] as int? ?? 1) * 1357).toString()}',
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

  Widget _buildServicesCard(int basePrice) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _ServiceTile(
            icon: Icons.video_call_rounded,
            color: Colors.blue,
            title: 'Konsultasi Online',
            subtitle: 'Chat & Video Call langsung dengan dokter',
            price: basePrice,
            formatPrice: _formatPrice,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _ServiceTile(
            icon: Icons.local_hospital_rounded,
            color: Colors.green,
            title: 'Tatap Muka',
            subtitle: 'Kunjungi dokter langsung di klinik',
            price: (basePrice * 1.5).toInt(),
            formatPrice: _formatPrice,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _ServiceTile(
            icon: Icons.home_rounded,
            color: Colors.orange,
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
        'colorVal': 0xFF3949AB,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.15),
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
                            fontWeight: FontWeight.w600, fontSize: 14),
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
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review['comment'] as String,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: Colors.black87),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(Color accentColor, int price) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Price info
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Konsultasi Online',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text(
                'Rp ${_formatPrice(price)}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Chat button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/chat');
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor),
                foregroundColor: accentColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Book appointment button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur buat janji akan segera hadir'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text('Buat Janji'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87),
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
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.grey[200]);
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
    return Container(
      width: 68,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color:
            active ? const Color(0xFF2196F3) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: active ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hours,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: active
                  ? Colors.white.withOpacity(0.9)
                  : Colors.grey[400],
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Text(
        'Rp ${formatPrice(price)}',
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 13),
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
