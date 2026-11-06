/// Model data Web Dashboard Admin Rumah Sakit.
///
/// Model di sini hanya untuk kebutuhan role `hospital_admin`; model pasien,
/// dokter, dan obat yang dipakai aplikasi mobile tidak diubah.
library;

/// Status alur verifikasi resep.
enum PrescriptionStatus {
  pendingVerification('pending_verification', 'Menunggu Verifikasi'),
  verified('verified', 'Terverifikasi'),
  needsClarification('needs_clarification', 'Butuh Klarifikasi'),
  cancelled('cancelled', 'Dibatalkan');

  const PrescriptionStatus(this.dbValue, this.label);

  /// Nilai kolom `prescriptions.status` di Supabase.
  final String dbValue;

  /// Label berbahasa Indonesia untuk UI.
  final String label;

  static PrescriptionStatus fromDb(Object? value) {
    final raw = value?.toString();
    for (final status in values) {
      if (status.dbValue == raw) return status;
    }
    return PrescriptionStatus.pendingVerification;
  }

  bool get isPending => this == PrescriptionStatus.pendingVerification;

  bool get isVerified => this == PrescriptionStatus.verified;

  bool get isNeedsClarification =>
      this == PrescriptionStatus.needsClarification;
}

/// Tingkat risiko pasien pasca rawat inap.
enum RiskLevel {
  low('low', 'Rendah', 0),
  medium('medium', 'Sedang', 1),
  high('high', 'Tinggi', 2);

  const RiskLevel(this.dbValue, this.label, this.weight);

  final String dbValue;
  final String label;
  final int weight;

  static RiskLevel fromDb(Object? value) {
    final raw = value?.toString();
    for (final level in values) {
      if (level.dbValue == raw) return level;
    }
    return RiskLevel.low;
  }

  bool get isHigh => this == RiskLevel.high;
}

/// Jenis peringatan yang tampil di halaman pemantauan.
enum AlertType {
  missedDose('missed_dose', 'Dosis terlewat'),
  complaint('complaint', 'Keluhan pasien');

  const AlertType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AlertType fromDb(Object? value) => switch (value?.toString()) {
    'complaint' => AlertType.complaint,
    _ => AlertType.missedDose,
  };
}

/// Identitas admin + rumah sakit tempat ia bertugas.
///
/// `hospitalId` berasal dari `user_roles.hospital_id`; seluruh RLS Supabase
/// memakai nilai ini sebagai batas data.
class HospitalAdminProfile {
  const HospitalAdminProfile({
    this.adminName = 'Admin Rumah Sakit',
    this.email = '',
    this.hospitalId = '',
    this.hospitalName = 'Rumah Sakit',
    this.hospitalCity = '',
  });

  factory HospitalAdminProfile.fromRow(Map<String, dynamic> row) {
    final hospital = _firstMap(row['hospitals']);
    return HospitalAdminProfile(
      adminName: _asString(row['full_name']),
      email: _asString(row['email']),
      hospitalId: _asString(row['hospital_id']),
      hospitalName: _asString(hospital?['name'], fallback: 'Rumah Sakit'),
      hospitalCity: _asString(hospital?['city']),
    );
  }

  final String adminName;
  final String email;
  final String hospitalId;
  final String hospitalName;
  final String hospitalCity;

  HospitalAdminProfile copyWith({
    String? adminName,
    String? email,
    String? hospitalId,
    String? hospitalName,
    String? hospitalCity,
  }) {
    return HospitalAdminProfile(
      adminName: adminName ?? this.adminName,
      email: email ?? this.email,
      hospitalId: hospitalId ?? this.hospitalId,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalCity: hospitalCity ?? this.hospitalCity,
    );
  }
}

/// Angka kartu ringkasan dashboard.
class HospitalAdminSummary {
  const HospitalAdminSummary({
    this.hospitalName = 'Rumah Sakit',
    this.activePatients = 0,
    this.pendingPrescriptions = 0,
    this.verifiedPrescriptions = 0,
    this.adherenceScore = 0,
    this.highRiskAlerts = 0,
    this.openAlerts = 0,
  });

  factory HospitalAdminSummary.fromJson(Map<String, dynamic> json) {
    return HospitalAdminSummary(
      hospitalName: _asString(json['hospital_name'], fallback: 'Rumah Sakit'),
      activePatients: _asInt(json['active_patients']),
      pendingPrescriptions: _asInt(json['pending_prescriptions']),
      verifiedPrescriptions: _asInt(json['verified_prescriptions']),
      adherenceScore: _asDouble(json['adherence_score']),
      highRiskAlerts: _asInt(json['high_risk_alerts']),
      openAlerts: _asInt(json['open_alerts']),
    );
  }

  final String hospitalName;
  final int activePatients;
  final int pendingPrescriptions;
  final int verifiedPrescriptions;
  final double adherenceScore;
  final int highRiskAlerts;
  final int openAlerts;

  /// Skor kepatuhan dengan satu angka desimal, mis. `86.4`.
  String get adherenceLabel => adherenceScore.toStringAsFixed(1);
}

/// Satu obat dalam resep yang diverifikasi admin.
class PrescriptionDrug {
  const PrescriptionDrug({
    required this.name,
    this.dose = '',
    this.frequencyPerDay = 1,
    this.durationDays = 1,
    this.instructions = '',
  });

  factory PrescriptionDrug.fromRow(Map<String, dynamic> row) {
    return PrescriptionDrug(
      name: _asString(row['medication_name']),
      dose: _asString(row['dose']),
      frequencyPerDay: _asInt(row['frequency_per_day'], fallback: 1),
      durationDays: _asInt(row['duration_days'], fallback: 1),
      instructions: _asString(row['special_instructions']),
    );
  }

  final String name;
  final String dose;
  final int frequencyPerDay;
  final int durationDays;
  final String instructions;

  /// Ringkasan singkat untuk chip di tabel, mis. `500 mg • 3x sehari`.
  String get summary {
    final parts = <String>[
      if (dose.isNotEmpty) dose,
      '$frequencyPerDay× sehari',
      '$durationDays hari',
    ];
    return parts.join(' • ');
  }

  Map<String, dynamic> toRow() => {
    'medication_name': name,
    'dose': dose,
    'frequency_per_day': frequencyPerDay,
    'duration_days': durationDays,
    'special_instructions': instructions,
  };

  PrescriptionDrug copyWith({
    String? name,
    String? dose,
    int? frequencyPerDay,
    int? durationDays,
    String? instructions,
  }) {
    return PrescriptionDrug(
      name: name ?? this.name,
      dose: dose ?? this.dose,
      frequencyPerDay: frequencyPerDay ?? this.frequencyPerDay,
      durationDays: durationDays ?? this.durationDays,
      instructions: instructions ?? this.instructions,
    );
  }
}

/// Resep dokter beserta pasien dan rincian obatnya.
class AdminPrescription {
  const AdminPrescription({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.medicalRecordNo = '',
    this.doctorName = '',
    this.status = PrescriptionStatus.pendingVerification,
    this.doctorNote = '',
    this.adminNote = '',
    this.drugs = const [],
    this.createdAt,
  });

  factory AdminPrescription.fromRow(Map<String, dynamic> row) {
    final patient = _firstMap(row['hospital_patients']);
    final rawItems = row['prescription_items'];
    final items = <PrescriptionDrug>[];

    if (rawItems is List) {
      final maps = rawItems.whereType<Map<String, dynamic>>().toList()
        ..sort(
          (a, b) => _asInt(a['position']).compareTo(_asInt(b['position'])),
        );
      for (final item in maps) {
        items.add(PrescriptionDrug.fromRow(item));
      }
    }

    return AdminPrescription(
      id: _asString(row['id']),
      patientId: _asString(patient?['id']),
      patientName: _asString(patient?['full_name'], fallback: 'Pasien'),
      medicalRecordNo: _asString(patient?['medical_record_no']),
      doctorName: _asString(row['doctor_name'], fallback: 'Dokter'),
      status: PrescriptionStatus.fromDb(row['status']),
      doctorNote: _asString(row['doctor_note']),
      adminNote: _asString(row['admin_note']),
      drugs: items,
      createdAt: _asDate(row['created_at']),
    );
  }

  final String id;
  final String patientId;
  final String patientName;
  final String medicalRecordNo;
  final String doctorName;
  final PrescriptionStatus status;
  final String doctorNote;
  final String adminNote;
  final List<PrescriptionDrug> drugs;
  final DateTime? createdAt;

  String get medicationSummary {
    if (drugs.isEmpty) return 'Belum ada rincian obat';
    return drugs.map((drug) => drug.name).join(', ');
  }

  String get scheduleSummary {
    if (drugs.isEmpty) return '-';
    final maxDays = drugs
        .map((drug) => drug.durationDays)
        .reduce((a, b) => a > b ? a : b);
    return '${drugs.length} obat • maksimal $maxDays hari';
  }

  AdminPrescription copyWith({
    String? patientId,
    String? patientName,
    String? medicalRecordNo,
    String? doctorName,
    PrescriptionStatus? status,
    String? doctorNote,
    String? adminNote,
    List<PrescriptionDrug>? drugs,
    DateTime? createdAt,
  }) {
    return AdminPrescription(
      id: id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      medicalRecordNo: medicalRecordNo ?? this.medicalRecordNo,
      doctorName: doctorName ?? this.doctorName,
      status: status ?? this.status,
      doctorNote: doctorNote ?? this.doctorNote,
      adminNote: adminNote ?? this.adminNote,
      drugs: drugs ?? this.drugs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Baris tabel pemantauan pasien pasca rawat inap.
class MonitoredPatient {
  const MonitoredPatient({
    required this.id,
    required this.name,
    this.medicalRecordNo = '',
    this.doctorName = '',
    this.diagnosis = '',
    this.riskLevel = RiskLevel.low,
    this.adherenceScore = 0,
    this.missedDosesToday = 0,
    this.openReports = 0,
    this.pendingPrescriptions = 0,
    this.dischargeDate,
    this.lastAdherenceDate,
    this.isActive = true,
  });

  factory MonitoredPatient.fromRow(Map<String, dynamic> row) {
    return MonitoredPatient(
      id: _asString(row['id']),
      name: _asString(row['full_name'], fallback: 'Pasien'),
      medicalRecordNo: _asString(row['medical_record_no']),
      doctorName: _asString(
        row['attending_doctor_name'],
        fallback: 'Belum ditentukan',
      ),
      diagnosis: _asString(row['diagnosis']),
      riskLevel: RiskLevel.fromDb(row['risk_level']),
      adherenceScore: _asDouble(row['adherence_score']),
      missedDosesToday: _asInt(row['missed_doses_today']),
      openReports: _asInt(row['open_reports']),
      pendingPrescriptions: _asInt(row['pending_prescriptions']),
      dischargeDate: _asDate(row['discharge_date']),
      lastAdherenceDate: _asDate(row['last_adherence_date']),
      isActive: row['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String medicalRecordNo;
  final String doctorName;
  final String diagnosis;
  final RiskLevel riskLevel;
  final double adherenceScore;
  final int missedDosesToday;
  final int openReports;
  final int pendingPrescriptions;
  final DateTime? dischargeDate;
  final DateTime? lastAdherenceDate;
  final bool isActive;

  bool get hasMissedDose => missedDosesToday > 0;

  bool get hasOpenReport => openReports > 0;

  /// Membutuhkan perhatian admin: melewatkan dosis, mengeluh, risiko tinggi,
  /// atau masih ada resep yang menunggu verifikasi.
  bool get needsAttention =>
      hasMissedDose ||
      hasOpenReport ||
      pendingPrescriptions > 0 ||
      riskLevel.isHigh;

  /// Pasien dengan kepatuhan di bawah 70% dianggap tidak patuh.
  bool get isNonAdherent => adherenceScore < 70;

  String get adherenceLabel => '${adherenceScore.toStringAsFixed(0)}%';
}

/// Peringatan realtime (dosis terlewat atau keluhan pasien).
class AdherenceAlert {
  const AdherenceAlert({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.type = AlertType.missedDose,
    this.severity = RiskLevel.medium,
    this.message = '',
    this.createdAt,
  });

  factory AdherenceAlert.fromRow(Map<String, dynamic> row) {
    return AdherenceAlert(
      id: _asString(row['id']),
      patientId: _asString(row['hospital_patient_id']),
      patientName: _asString(row['patient_name'], fallback: 'Pasien'),
      type: AlertType.fromDb(row['alert_type']),
      severity: RiskLevel.fromDb(row['severity']),
      message: _asString(row['message']),
      createdAt: _asDate(row['created_at']),
    );
  }

  final String id;
  final String patientId;
  final String patientName;
  final AlertType type;
  final RiskLevel severity;
  final String message;
  final DateTime? createdAt;

  bool get isCritical => severity.isHigh;
}

// ─── Helper parsing ───────────────────────────────────────────────────────────

Map<String, dynamic>? _firstMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is Map<String, dynamic>) return first;
  }
  return null;
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
