import 'package:Telehealth/data/services/password_reset_service.dart';

/// Data yang dibawa ke layar konfirmasi setelah tautan reset dikirim.
class ResetLinkSentArgs {
  const ResetLinkSentArgs({required this.email});

  final String email;

  String get maskedEmail => PasswordResetService.maskEmail(email);
}
