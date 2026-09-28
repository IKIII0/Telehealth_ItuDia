import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Map<String, String> _dummy = {
    'name': 'John Doe',
    'email': 'john.doe@example.com',
    'phone': '+62 812 3456 7890',
    'birthDate': '15 Januari 1995',
    'gender': 'Laki-laki',
    'address': 'Jl. Sudirman No. 123, Jakarta Pusat',
    'bloodType': 'A+',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur edit profil akan segera hadir')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 8),
            _buildMenuCard(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFFBBDEFB),
              child: const Icon(Icons.person, size: 60, color: Color(0xFF2196F3)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _dummy['name']!,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dummy['email']!,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Pasien',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final rows = [
      {'icon': Icons.phone, 'label': 'Telepon', 'value': _dummy['phone']!},
      {'icon': Icons.cake, 'label': 'Tanggal Lahir', 'value': _dummy['birthDate']!},
      {'icon': Icons.wc, 'label': 'Jenis Kelamin', 'value': _dummy['gender']!},
      {'icon': Icons.location_on, 'label': 'Alamat', 'value': _dummy['address']!},
      {'icon': Icons.water_drop, 'label': 'Golongan Darah', 'value': _dummy['bloodType']!},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informasi Pribadi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(r['icon'] as IconData, size: 20, color: const Color(0xFF2196F3)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['label'] as String,
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(r['value'] as String,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            _menuItem(context, Icons.edit, 'Edit Profil', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur edit profil akan segera hadir')),
              );
            }),
            _divider(),
            _menuItem(context, Icons.lock_outline, 'Ganti Password', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur ganti password akan segera hadir')),
              );
            }),
            _divider(),
            _menuItem(context, Icons.notifications_outlined, 'Notifikasi', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur notifikasi akan segera hadir')),
              );
            }),
            _divider(),
            _menuItem(context, Icons.help_outline, 'Bantuan', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur bantuan akan segera hadir')),
              );
            }),
            _divider(),
            _menuItem(context, Icons.info_outline, 'Tentang Aplikasi', onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Telehealth App',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Telehealth App',
              );
            }),
            _divider(),
            _menuItem(
              context,
              Icons.logout,
              'Keluar',
              color: Colors.red,
              onTap: () {
                showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar'),
                    content: const Text('Apakah Anda yakin ingin keluar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ).then((confirmed) {
                  if (confirmed == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Berhasil keluar')),
                    );
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label,
      {VoidCallback? onTap, Color? color}) {
    final c = color ?? const Color(0xFF424242);
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF2196F3)),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56);
}
