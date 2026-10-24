import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/routing/route_error_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/login_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/register_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/splash_screen.dart';
import 'package:Telehealth/features/chat/presentation/pages/chat_room_page.dart';
import 'package:Telehealth/features/chat/presentation/pages/conversation_list_page.dart';
import 'package:Telehealth/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:Telehealth/features/doctor/presentation/pages/doctor_detail_page.dart';
import 'package:Telehealth/features/doctor/presentation/pages/doctor_list_page.dart';
import 'package:Telehealth/features/health_journal/presentation/pages/add_journal_entry_page.dart';
import 'package:Telehealth/features/health_journal/presentation/pages/health_journal_page.dart';
import 'package:Telehealth/features/medication/presentation/pages/medication_reminder_page.dart';
import 'package:Telehealth/features/profile/presentation/pages/profile_page.dart';
import 'package:Telehealth/features/symptom_checker/presentation/pages/symptom_checker_page.dart';

/// Konfigurasi navigasi utama aplikasi.
///
/// Satu instance [router] dipakai oleh `MaterialApp.router` agar konfigurasi
/// tidak dibuat ulang pada setiap rebuild.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splashPath,
    redirect: _redirect,
    errorBuilder: (context, state) =>
        RouteErrorPage(message: state.error?.toString()),
    routes: [
      GoRoute(
        name: AppRoutes.splashName,
        path: AppRoutes.splashPath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: AppRoutes.loginName,
        path: AppRoutes.loginPath,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        name: AppRoutes.registerName,
        path: AppRoutes.registerPath,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        name: AppRoutes.patientDashboardName,
        path: AppRoutes.patientDashboardPath,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        name: AppRoutes.patientProfileName,
        path: AppRoutes.patientProfilePath,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        name: AppRoutes.patientDoctorsName,
        path: AppRoutes.patientDoctorsPath,
        builder: (context, state) => const DoctorListPage(),
      ),
      GoRoute(
        name: AppRoutes.patientDoctorDetailName,
        path: AppRoutes.patientDoctorDetailPath,
        builder: (context, state) =>
            DoctorDetailPage(doctorId: state.pathParameters['doctorId']!),
      ),
      GoRoute(
        name: AppRoutes.patientChatName,
        path: AppRoutes.patientChatPath,
        builder: (context, state) => const ConversationListPage(),
      ),
      GoRoute(
        name: AppRoutes.patientChatRoomName,
        path: AppRoutes.patientChatRoomPath,
        builder: (context, state) => ChatRoomPage(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
      GoRoute(
        name: AppRoutes.patientJournalName,
        path: AppRoutes.patientJournalPath,
        builder: (context, state) => const HealthJournalPage(),
      ),
      GoRoute(
        name: AppRoutes.patientJournalAddName,
        path: AppRoutes.patientJournalAddPath,
        builder: (context, state) => const AddJournalEntryPage(),
      ),
      GoRoute(
        name: AppRoutes.patientSymptomCheckerName,
        path: AppRoutes.patientSymptomCheckerPath,
        builder: (context, state) => const SymptomCheckerPage(),
      ),
      GoRoute(
        name: AppRoutes.patientMedicationName,
        path: AppRoutes.patientMedicationPath,
        builder: (context, state) => const MedicationReminderPage(),
      ),
    ],
  );

  /// Redirect kompatibilitas untuk path lama dan root.
  static String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    if (location == '/') {
      return AppRoutes.splashPath;
    }
    return AppRoutes.legacyRedirects[location];
  }
}
