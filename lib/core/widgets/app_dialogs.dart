import 'package:flutter/material.dart';

/// Menampilkan dialog konfirmasi (mis. untuk aksi destruktif seperti hapus).
/// Mengembalikan `true` bila pengguna menekan tombol konfirmasi.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  String cancelLabel = 'Batal',
  bool destructive = true,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Snackbar pesan singkat: hijau untuk sukses, merah untuk gagal.
void showAppSnack(BuildContext context, String message, {bool success = true}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade600 : scheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
