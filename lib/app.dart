import 'package:flutter/material.dart';

import 'package:Telehealth/core/routing/app_router.dart';
import 'package:Telehealth/core/theme/app_theme.dart';

class TelehealthApp extends StatelessWidget {
  const TelehealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Telehealth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
    );
  }
}
