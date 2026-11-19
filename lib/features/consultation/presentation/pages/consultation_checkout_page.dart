import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/async_state.dart';
import 'package:Telehealth/data/models/doctor.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/data/repositories/chat_repository.dart';
import 'package:Telehealth/data/repositories/consultation_repository.dart';
import 'package:Telehealth/data/repositories/conversation_repository.dart';
import 'package:Telehealth/data/repositories/doctor_repository.dart';

/// Halaman checkout konsultasi (alur seperti Halodoc):
///   1. Pilih profil pasien
///   2. Pilih metode pembayaran
///   3. Bayar → sesi chat langsung dibuka
///
/// Tidak ada penjadwalan; konsultasi dimulai segera setelah pembayaran.
class ConsultationCheckoutPage extends StatefulWidget {
  const ConsultationCheckoutPage({
    super.key,
    required this.doctorId,
    this.doctor,
  });

  final String doctorId;

  /// Data dokter yang sudah dimuat di halaman sebelumnya (opsional).
  final Doctor? doctor;

  @override
  State<ConsultationCheckoutPage> createState() =>
      _ConsultationCheckoutPageState();
}

class _ConsultationCheckoutPageState extends State<ConsultationCheckoutPage> {
  static const int _serviceFee = 2000;

  late final List<_PatientProfile> _profiles;
  late final List<_PaymentMethod> _methods;
  final _complaintCtrl = TextEditingController();

  Doctor? _doctor;
  bool _loadingDoctor = false;

  int _selectedProfile = 0;
  int _selectedMethod = 0;
  bool _paying = false;

  @override
  void dispose() {
    _complaintCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    final userName = AuthRepository.instance.currentUser?.name ?? 'Saya';
    _profiles = [
      _PatientProfile(
        name: userName,
        relation: 'Saya sendiri',
        icon: Icons.person_rounded,
      ),
      const _PatientProfile(
        name: 'Budi',
        relation: 'Ayah • 54 tahun',
        icon: Icons.man_rounded,
      ),
      const _PatientProfile(
        name: 'Rina',
        relation: 'Ibu • 49 tahun',
        icon: Icons.woman_rounded,
      ),
    ];
    _methods = const [
      _PaymentMethod(
        label: 'Transfer Bank',
        detail: 'BCA • Virtual Account',
        icon: Icons.account_balance_rounded,
      ),
      _PaymentMethod(
        label: 'GoPay',
        detail: 'Saldo Rp 250.000',
        icon: Icons.account_balance_wallet_rounded,
      ),
      _PaymentMethod(
        label: 'OVO',
        detail: 'Saldo Rp 180.000',
        icon: Icons.wallet_rounded,
      ),
      _PaymentMethod(
        label: 'Kartu Kredit',
        detail: 'Visa •••• 4242',
        icon: Icons.credit_card_rounded,
      ),
    ];
    if (_doctor == null) _loadDoctor();
  }

  Future<void> _loadDoctor() async {
    setState(() => _loadingDoctor = true);
    try {
      final doctor = await DoctorRepository.instance.findById(widget.doctorId);
      if (!mounted) return;
      setState(() {
        _doctor = doctor;
        _loadingDoctor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDoctor = false);
    }
  }

  int get _total => (_doctor?.price ?? 0) + _serviceFee;

  Future<void> _payAndStart() async {
    final doctor = _doctor;
    if (doctor == null) return;
    setState(() => _paying = true);
    try {
      // Simulasi proses pembayaran.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Bila Supabase aktif, buat permintaan konsultasi sungguhan agar muncul
      // di dashboard dokter. Tanpa itu, aplikasi memakai alur simulasi chat.
      final repo = ConsultationRepository.instance;
      if (repo.isRemote) {
        final complaint = _complaintCtrl.text.trim();
        if (complaint.isEmpty) {
          if (!mounted) return;
          setState(() => _paying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tuliskan keluhan Anda terlebih dahulu.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final profile = _profiles[_selectedProfile];
        final session = await repo.createRequest(
          doctorDirectoryId: doctor.id,
          patientName: profile.name,
          patientRelation: profile.relation,
          complaint: complaint,
          consultationType: 'Chat Dokter',
          fee: _total,
        );
        if (!mounted) return;
        if (session == null) {
          setState(() => _paying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Dokter ini belum terhubung ke akun praktiknya. '
                'Permintaan tidak dapat dikirim.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        setState(() => _paying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permintaan konsultasi terkirim. Menunggu dokter.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed(AppRoutes.patientDashboardName);
        }
        return;
      }

      final conversation = await ConversationRepository.instance
          .ensureForDoctor(doctor);
      // Beri pesan pembuka agar sesi tidak kosong saat pertama dibuka.
      final messages = await ChatRepository.instance.fetchMessages(
        conversation.id,
      );
      if (messages.isEmpty) {
        await ChatRepository.instance.autoReply(
          conversation.id,
          text:
              'Halo, saya ${doctor.name}. Silakan sampaikan keluhan Anda, '
              'saya akan membantu.',
        );
      }
      if (!mounted) return;
      context.pushReplacementNamed(
        AppRoutes.patientChatRoomName,
        pathParameters: {'conversationId': conversation.id},
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran gagal. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatPrice(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doctor = _doctor;

    if (doctor == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Konsultasi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _loadingDoctor
            ? const LoadingView(message: 'Memuat data dokter...')
            : ErrorView(
                message: 'Dokter tidak ditemukan.',
                onRetry: _loadDoctor,
              ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Konsultasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildDoctorSummary(scheme, doctor),
          const SizedBox(height: 20),
          _sectionLabel('Pilih profil pasien'),
          const SizedBox(height: 8),
          ..._profiles.asMap().entries.map(
            (entry) => _buildProfileTile(entry.key, entry.value, scheme),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Keluhan yang dikonsultasikan'),
          const SizedBox(height: 8),
          _buildComplaintField(),
          const SizedBox(height: 20),
          _sectionLabel('Metode pembayaran'),
          const SizedBox(height: 8),
          ..._methods.asMap().entries.map(
            (entry) => _buildMethodTile(entry.key, entry.value, scheme),
          ),
          const SizedBox(height: 20),
          _buildSummary(scheme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total bayar',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPrice(_total),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _paying ? null : _payAndStart,
                  icon: _paying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    _paying ? 'Memproses...' : 'Bayar & Mulai Konsultasi',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildComplaintField() {
    return TextField(
      key: const Key('consultation_complaint_field'),
      controller: _complaintCtrl,
      maxLines: 3,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: 'Contoh: Demam 3 hari disertai nyeri tenggorokan.',
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  Widget _buildDoctorSummary(ColorScheme scheme, Doctor doctor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: doctor.avatarColor.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: doctor.avatarColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.specialization,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatPrice(doctor.price),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(
    int index,
    _PatientProfile profile,
    ColorScheme scheme,
  ) {
    final selected = _selectedProfile == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedProfile = index),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(profile.icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      profile.relation,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Radio<int>(
                value: index,
                groupValue: _selectedProfile,
                activeColor: scheme.primary,
                onChanged: (value) => setState(() => _selectedProfile = value!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTile(
    int index,
    _PaymentMethod method,
    ColorScheme scheme,
  ) {
    final selected = _selectedMethod == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedMethod = index),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(method.icon, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      method.detail,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Radio<int>(
                value: index,
                groupValue: _selectedMethod,
                activeColor: scheme.primary,
                onChanged: (value) => setState(() => _selectedMethod = value!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _summaryRow('Biaya konsultasi', _formatPrice(_doctor?.price ?? 0)),
          const SizedBox(height: 8),
          _summaryRow('Biaya layanan', _formatPrice(_serviceFee)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _summaryRow(
            'Total',
            _formatPrice(_total),
            bold: true,
            color: scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PatientProfile {
  const _PatientProfile({
    required this.name,
    required this.relation,
    required this.icon,
  });

  final String name;
  final String relation;
  final IconData icon;
}

class _PaymentMethod {
  const _PaymentMethod({
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String detail;
  final IconData icon;
}
