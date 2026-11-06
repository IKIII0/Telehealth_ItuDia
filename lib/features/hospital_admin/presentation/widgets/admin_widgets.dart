import 'package:flutter/material.dart';

import 'package:Telehealth/data/models/hospital_admin.dart';
import 'package:Telehealth/features/hospital_admin/presentation/theme/admin_theme.dart';

/// Header halaman admin: judul, deskripsi singkat, dan aksi di kanan.
///
/// Otomatis menumpuk aksi di bawah judul pada layar sempit.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AdminColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AdminColors.textMuted,
            ),
          ),
        ],
      ],
    );

    if (actions.isEmpty) return heading;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        );
      },
    );
  }
}

/// Kartu putih dengan border halus, dipakai untuk semua panel dashboard.
class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F2E3A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          if (title != null) const Divider(height: 24),
          if (child != null) Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Kartu angka ringkasan dashboard.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accent,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: 0.35)
              : AdminColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F2E3A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const Spacer(),
              if (highlight)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AdminColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nada warna badge status.
enum AdminBadgeTone { success, warning, danger, info, neutral }

/// Badge status berwarna sesuai makna medis:
/// hijau = aman/terverifikasi, kuning = menunggu, merah = risiko.
class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({
    super.key,
    required this.label,
    this.tone = AdminBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final AdminBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      AdminBadgeTone.success => (AdminColors.successSoft, AdminColors.success),
      AdminBadgeTone.warning => (AdminColors.warningSoft, AdminColors.warning),
      AdminBadgeTone.danger => (AdminColors.dangerSoft, AdminColors.danger),
      AdminBadgeTone.info => (AdminColors.infoSoft, AdminColors.info),
      AdminBadgeTone.neutral => (
        AdminColors.surfaceMuted,
        AdminColors.textMuted,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar progres tipis untuk skor kepatuhan.
class AdminProgressBar extends StatelessWidget {
  const AdminProgressBar({
    super.key,
    required this.value,
    this.color = AdminColors.success,
    this.height = 8,
  });

  /// Nilai 0..100.
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / 100).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: AdminColors.border,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Titik indikator "live" dengan efek glow.
class AdminLiveDot extends StatelessWidget {
  const AdminLiveDot({
    super.key,
    this.color = AdminColors.success,
    this.size = 9,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

/// Avatar inisial untuk pasien/admin.
class AdminInitialsAvatar extends StatelessWidget {
  const AdminInitialsAvatar({
    super.key,
    required this.name,
    this.color = AdminColors.primary,
    this.size = 40,
  });

  final String name;
  final Color color;
  final double size;

  String get _initials {
    final parts = name
        .replaceAll('dr.', '')
        .replaceAll(',', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Tampilan kosong yang konsisten untuk daftar/tabel admin.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AdminColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AdminColors.textMuted, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AdminColors.textMuted,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Chip kecil "Mode demo" agar penguji tahu data bukan dari Supabase.
class AdminDemoBadge extends StatelessWidget {
  const AdminDemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 13, color: AdminColors.warning),
          SizedBox(width: 5),
          Text(
            'Data demo',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AdminColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pemetaan status → warna ─────────────────────────────────────────────────

AdminBadgeTone badgeToneForPrescription(PrescriptionStatus status) {
  return switch (status) {
    PrescriptionStatus.pendingVerification => AdminBadgeTone.warning,
    PrescriptionStatus.verified => AdminBadgeTone.success,
    PrescriptionStatus.needsClarification => AdminBadgeTone.info,
    PrescriptionStatus.cancelled => AdminBadgeTone.danger,
  };
}

IconData iconForPrescription(PrescriptionStatus status) {
  return switch (status) {
    PrescriptionStatus.pendingVerification => Icons.hourglass_top_rounded,
    PrescriptionStatus.verified => Icons.verified_rounded,
    PrescriptionStatus.needsClarification => Icons.forum_outlined,
    PrescriptionStatus.cancelled => Icons.cancel_outlined,
  };
}

AdminBadgeTone badgeToneForRisk(RiskLevel level) {
  return switch (level) {
    RiskLevel.high => AdminBadgeTone.danger,
    RiskLevel.medium => AdminBadgeTone.warning,
    RiskLevel.low => AdminBadgeTone.success,
  };
}

Color colorForRisk(RiskLevel level) {
  return switch (level) {
    RiskLevel.high => AdminColors.danger,
    RiskLevel.medium => AdminColors.warning,
    RiskLevel.low => AdminColors.success,
  };
}

Color colorForAdherence(double score) {
  if (score < 70) return AdminColors.danger;
  if (score < 85) return AdminColors.warning;
  return AdminColors.success;
}

/// Status obat pasien untuk kolom tabel pemantauan.
({String label, AdminBadgeTone tone, IconData icon}) medicationStatusOf(
  MonitoredPatient patient,
) {
  if (patient.pendingPrescriptions > 0) {
    return (
      label: 'Menunggu verifikasi',
      tone: AdminBadgeTone.warning,
      icon: Icons.hourglass_top_rounded,
    );
  }
  if (patient.hasMissedDose) {
    return (
      label: 'Dosis terlewat',
      tone: AdminBadgeTone.danger,
      icon: Icons.alarm_off_rounded,
    );
  }
  if (patient.isNonAdherent) {
    return (
      label: 'Kurang patuh',
      tone: AdminBadgeTone.danger,
      icon: Icons.trending_down_rounded,
    );
  }
  return (
    label: 'Patuh',
    tone: AdminBadgeTone.success,
    icon: Icons.check_circle_outline_rounded,
  );
}

// ─── Format tanggal ──────────────────────────────────────────────────────────

const List<String> _adminMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String adminFormatDate(DateTime? date) {
  if (date == null) return '-';
  final local = date.toLocal();
  return '${local.day} ${_adminMonths[local.month - 1]} ${local.year}';
}

String adminFormatDateTime(DateTime? date) {
  if (date == null) return '-';
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${adminFormatDate(local)} • $hour:$minute';
}

String adminRelativeTime(DateTime? date) {
  if (date == null) return '-';
  final now = DateTime.now();
  final diff = now.difference(date.toLocal());
  if (diff.isNegative || diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return adminFormatDate(date);
}
