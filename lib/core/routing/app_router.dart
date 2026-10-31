import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/routing/route_error_page.dart';
import 'package:Telehealth/core/widgets/patient_shell_scaffold.dart';
// ignore_for_file: directives_ordering
import 'package:Telehealth/data/models/user.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/features/authentication/presentation/pages/login_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/register_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/reset_link_sent_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/reset_password_page.dart';
import 'package:Telehealth/features/authentication/presentation/pages/splash_screen.dart';
import 'package:Telehealth/features/authentication/presentation/models/reset_link_sent_args.dart';
import 'package:Telehealth/features/chat/presentation/pages/chat_room_page.dart';
import 'package:Telehealth/features/chat/presentation/pages/conversation_list_page.dart';
import 'package:Telehealth/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:Telehealth/features/doctor/presentation/pages/doctor_detail_page.dart';
import 'package:Telehealth/features/doctor/presentation/pages/doctor_list_page.dart';
import 'package:Telehealth/features/doctor_dashboard/presentation/pages/doctor_dashboard_page.dart';
import 'package:Telehealth/features/health_journal/presentation/pages/add_journal_entry_page.dart';
import 'package:Telehealth/features/health_journal/presentation/pages/health_journal_page.dart';
import 'package:Telehealth/features/medication/presentation/pages/medication_reminder_page.dart';
import 'package:Telehealth/features/profile/presentation/pages/profile_page.dart';
import 'package:Telehealth/features/symptom_checker/presentation/pages/symptom_checker_page.dart';

/// Konfigurasi navigasi utama aplikasi.
///
/// Satu instance [router] dipakai oleh `MaterialApp.router` agar konfigurasi
/// tidak dibuat ulang pada setiap rebuild.
///
/// Tab utama pasien (Dashboard, Cek Gejala, Chat, Profil) dibungkus dalam
/// [StatefulShellRoute] agar [PatientShellScaffold] (beserta navbar-nya)
/// tetap statis dan tidak hilang saat berpindah antar halaman tab.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splashPath,
    refreshListenable: AuthRepository.instance,
    redirect: _redirect,
    errorBuilder: (context, state) =>
        RouteErrorPage(message: state.error?.toString()),
    routes: [
      // ── Publik ──────────────────────────────────────────────────────────────
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
        name: AppRoutes.resetPasswordName,
        path: AppRoutes.resetPasswordPath,
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        name: AppRoutes.resetPasswordSentName,
        path: AppRoutes.resetPasswordSentPath,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ResetLinkSentArgs) {
            return ResetLinkSentPage(args: extra);
          }
          // Url dibuka langsung tanpa data: kembali ke langkah pencarian.
          return const ResetPasswordPage();
        },
      ),

      // ── Pasien: tab utama dengan navbar persisten ────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PatientShellScaffold(navigationShell: navigationShell),
        branches: [
          // Branch 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.patientDashboardName,
                path: AppRoutes.patientDashboardPath,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          // Branch 1: Cek Gejala
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.patientSymptomCheckerName,
                path: AppRoutes.patientSymptomCheckerPath,
                builder: (context, state) => const SymptomCheckerPage(),
              ),
            ],
          ),
          // Branch 2: Chat Dokter
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.patientChatName,
                path: AppRoutes.patientChatPath,
                builder: (context, state) => const ConversationListPage(),
              ),
            ],
          ),
          // Branch 3: Profil
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.patientProfileName,
                path: AppRoutes.patientProfilePath,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ── Pasien: halaman detail (tanpa navbar shell) ──────────────────────────
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
        name: AppRoutes.patientMedicationName,
        path: AppRoutes.patientMedicationPath,
        builder: (context, state) => const MedicationReminderPage(),
      ),

      // ── Dokter ───────────────────────────────────────────────────────────────
      GoRoute(
        name: AppRoutes.doctorDashboardName,
        path: AppRoutes.doctorDashboardPath,
        builder: (context, state) => const DoctorDashboardPage(),
      ),
    ],
  );

  /// Redirect untuk kompatibilitas path lama, autentikasi, dan role.
  static String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    if (location == '/') {
      return AppRoutes.splashPath;
    }

    final legacyTarget = AppRoutes.legacyRedirects[location];
    if (legacyTarget != null) {
      return legacyTarget;
    }

    // Splash menjadi titik tunggu selama status sesi belum diketahui.
    if (location == AppRoutes.splashPath) {
      return null;
    }

    final auth = AuthRepository.instance;
    if (auth.status == AuthStatus.unknown) {
      return AppRoutes.splashPath;
    }

    final isPublic =
        location == AppRoutes.loginPath ||
        location == AppRoutes.registerPath ||
        location.startsWith(AppRoutes.resetPasswordPath);

    if (auth.status == AuthStatus.unauthenticated) {
      if (isPublic) return null;
      return Uri(
        path: AppRoutes.loginPath,
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }

    final user = auth.currentUser;
    if (user == null) {
      return AppRoutes.loginPath;
    }

    final role = user.role;

    if (isPublic) {
      return AppRoutes.homePathFor(role);
    }

    if (role == UserRole.patient && location.startsWith('/doctor/')) {
      return AppRoutes.patientDashboardPath;
    }
    if (role == UserRole.doctor && location.startsWith('/patient/')) {
      return AppRoutes.doctorDashboardPath;
    }

    return null;
  }
}
