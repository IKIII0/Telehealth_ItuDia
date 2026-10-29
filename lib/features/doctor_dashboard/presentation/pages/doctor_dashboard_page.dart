import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';

/// Halaman utama dokter.
///
/// Versi ini fokus pada validasi autentikasi dan role. Ringkasan konsultasi
/// lengkap ditambahkan pada tahap berikutnya.
class DoctorDashboardPage extends StatelessWidget {
  const DoctorDashboardPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthRepository.instance.signOut();
    if (!context.mounted) return;
    context.goNamed(AppRoutes.loginName);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = AuthRepository.instance.currentUser;
    final profile = user?.doctorProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Dokter'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Sesi dokter tidak ditemukan.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          Color.lerp(scheme.primary, Colors.black, 0.25)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selamat datang,',
                                style: TextStyle(
                                  color: scheme.onPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (profile != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  profile.specialization,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.science_outlined,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Data simulasi',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ringkasan permintaan, jadwal, dan riwayat '
                            'konsultasi akan tampil di halaman dokter.',
                          ),
                          if (profile != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Rumah sakit',
                              value: profile.hospital,
                            ),
                            _InfoRow(
                              label: 'Pengalaman',
                              value: '${profile.experienceYears} tahun',
                            ),
                            _InfoRow(
                              label: 'Nomor STR',
                              value: profile.strNumber,
                            ),
                            _InfoRow(
                              label: 'Verifikasi kredensial',
                              value: profile.verified
                                  ? 'Terverifikasi'
                                  : 'Belum diverifikasi',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
