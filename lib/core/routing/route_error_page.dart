import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Telehealth/core/routing/app_routes.dart';

/// Halaman yang ditampilkan ketika route tidak ditemukan.
class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Halaman Tidak Ditemukan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off_outlined, size: 64, color: scheme.error),
              const SizedBox(height: 16),
              const Text(
                'Halaman tidak ditemukan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message ?? 'Alamat yang Anda tuju tidak tersedia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.splashPath);
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
