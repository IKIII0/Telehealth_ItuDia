import 'package:flutter/material.dart';

import 'features/authentication/presentation/pages/splash_screen.dart';
import 'features/authentication/presentation/pages/login_page.dart';
import 'features/authentication/presentation/pages/register_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/health_journal/presentation/pages/health_journal_page.dart';
import 'features/health_journal/presentation/pages/add_journal_entry_page.dart';
import 'features/symptom_checker/presentation/pages/symptom_checker_page.dart';
import 'features/doctor/presentation/pages/doctor_list_page.dart';
import 'features/doctor/presentation/pages/doctor_detail_page.dart';
import 'features/chat/presentation/pages/conversation_list_page.dart';
import 'features/medication/presentation/pages/medication_reminder_page.dart';

class TelehealthApp extends StatelessWidget {
  const TelehealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telehealth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
        '/dashboard': (context) => const DashboardPage(),
        '/journal': (context) => const HealthJournalPage(),
        '/journal/add': (context) => const AddJournalEntryPage(),
        '/symptom-checker': (context) => const SymptomCheckerPage(),
        '/doctors': (context) => const DoctorListPage(),
        '/chat': (context) => const ConversationListPage(),
        '/medication': (context) => const MedicationReminderPage(),
      },
    );
  }
}
