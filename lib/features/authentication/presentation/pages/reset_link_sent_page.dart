import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/features/authentication/presentation/models/reset_link_sent_args.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Layar konfirmasi setelah tautan reset password Firebase dikirim.
class ResetLinkSentPage extends StatefulWidget {
  const ResetLinkSentPage({super.key, required this.args});

  final ResetLinkSentArgs args;

  @override
  State<ResetLinkSentPage> createState() => _ResetLinkSentPageState();
}

class _ResetLinkSentPageState extends State<ResetLinkSentPage> {
  bool _resending = false;

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);

    try {
      await AuthRepository.instance.passwordReset.sendPasswordResetLink(
        email: widget.args.email,
      );
      if (!mounted) return;
      showAppSnack(context, 'Tautan reset telah dikirim ulang');
    } on AuthException catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.message, success: false);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Gagal mengirim ulang tautan. Silakan coba lagi.',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Link Terkirim')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 38,
                    color: Colors.green.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Cek Email Anda',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Tautan reset password telah dikirim ke ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: widget.args.maskedEmail,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              const _StepTile(
                number: '1',
                text:
                    'Buka email dari Firebase dan tekan tautan reset password.',
              ),
              const SizedBox(height: 14),
              const _StepTile(
                number: '2',
                text: 'Buat kata sandi baru pada halaman yang terbuka.',
              ),
              const SizedBox(height: 14),
              const _StepTile(
                number: '3',
                text: 'Kembali ke aplikasi dan masuk dengan kata sandi baru.',
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tidak menemukan email? Periksa folder Spam/Promosi. '
                        'Tautan bersifat sekali pakai dan memiliki masa berlaku.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.loginPath),
                  child: const Text('Kembali ke Login'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _resending ? null : _resend,
                  child: _resending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kirim Ulang Tautan'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resending
                      ? null
                      : () => context.pushReplacementNamed(
                          AppRoutes.resetPasswordName,
                        ),
                  child: const Text('Gunakan email lain'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
