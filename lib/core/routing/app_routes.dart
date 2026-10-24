/// Nama dan path route aplikasi.
///
/// Navigasi antarlayar memakai nama route agar string path tidak tersebar
/// di banyak widget.
class AppRoutes {
  AppRoutes._();

  // ── Publik ─────────────────────────────────────────────────────────────────
  static const String splashName = 'splash';
  static const String splashPath = '/splash';

  static const String loginName = 'login';
  static const String loginPath = '/login';

  static const String registerName = 'register';
  static const String registerPath = '/register';

  // ── Pasien ─────────────────────────────────────────────────────────────────
  static const String patientDashboardName = 'patientDashboard';
  static const String patientDashboardPath = '/patient/dashboard';

  static const String patientProfileName = 'patientProfile';
  static const String patientProfilePath = '/patient/profile';

  static const String patientDoctorsName = 'patientDoctors';
  static const String patientDoctorsPath = '/patient/doctors';

  static const String patientDoctorDetailName = 'patientDoctorDetail';
  static const String patientDoctorDetailPath = '/patient/doctors/:doctorId';

  static const String patientChatName = 'patientChat';
  static const String patientChatPath = '/patient/chat';

  static const String patientChatRoomName = 'patientChatRoom';
  static const String patientChatRoomPath = '/patient/chat/:conversationId';

  static const String patientJournalName = 'patientJournal';
  static const String patientJournalPath = '/patient/journal';

  static const String patientJournalAddName = 'patientJournalAdd';
  static const String patientJournalAddPath = '/patient/journal/add';

  static const String patientSymptomCheckerName = 'patientSymptomChecker';
  static const String patientSymptomCheckerPath = '/patient/symptom-checker';

  static const String patientMedicationName = 'patientMedication';
  static const String patientMedicationPath = '/patient/medication';

  /// Redirect dari path lama (sebelum migrasi GoRouter) ke path baru.
  ///
  /// Dipertahankan agar tautan lama tetap berfungsi selama masa transisi.
  static const Map<String, String> legacyRedirects = {
    '/dashboard': patientDashboardPath,
    '/profile': patientProfilePath,
    '/journal': patientJournalPath,
    '/journal/add': patientJournalAddPath,
    '/symptom-checker': patientSymptomCheckerPath,
    '/doctors': patientDoctorsPath,
    '/chat': patientChatPath,
    '/medication': patientMedicationPath,
  };
}
