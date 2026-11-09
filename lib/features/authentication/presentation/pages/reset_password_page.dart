import 'dart:async';

import 'package:Telehealth/core/routing/app_routes.dart';
import 'package:Telehealth/core/widgets/app_dialogs.dart';
import 'package:Telehealth/core/widgets/app_logo.dart';
import 'package:Telehealth/data/models/reset_account.dart';
import 'package:Telehealth/data/repositories/auth_repository.dart';
import 'package:Telehealth/features/authentication/presentation/models/reset_link_sent_args.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Langkah reset password: cari akun berdasarkan email, lalu kirim tautan
/// reset resmi Firebase ke email yang tersamarkan.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();

  ResetAccount? _account;
  bool _searching = false;
  bool _sending = false;

  bool get _busy => _searching || _sending;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchAccount() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showAppSnack(context, 'Masukkan email akun Anda.', success: false);
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _searching = true;
      _account = null;
    });

    try {
      final account = await AuthRepository.instance.passwordReset
          .findAccountByEmail(email);
      if (!mounted) return;

      if (account == null) {
        showAppSnack(
          context,
          'Akun tidak ditemukan. Periksa email yang Anda masukkan.',
          success: false,
        );
        return;
      }
      setState(() => _account = account);
    } on AuthException catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.message, success: false);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Gagal mencari akun. Silakan coba lagi.',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearAccountOnEdit(String _) {
    if (_account == null) return;
    setState(() => _account = null);
  }

  Future<void> _sendLink() async {
    final account = _account;
    if (_busy || account == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    try {
      await AuthRepository.instance.passwordReset.sendPasswordResetLink(
        email: account.email,
      );
      if (!mounted) return;
      unawaited(
        context.pushNamed(
          AppRoutes.resetPasswordSentName,
          extra: ResetLinkSentArgs(email: account.email),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.message, success: false);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Gagal mengirim tautan reset. Silakan coba lagi.',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final account = _account;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AppLogo(size: 44, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Lupa Password?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan email akun Anda. Kami akan mengirim tautan reset '
                'password ke email yang terdaftar.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAccount(),
                onChanged: _clearAccountOnEdit,
                decoration: const InputDecoration(
                  labelText: 'Email Akun',
                  hintText: 'contoh@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _searchAccount,
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.manage_search),
                  label: Text(_searching ? 'Mencari akun...' : 'Cari Akun'),
                ),
              ),
              const SizedBox(height: 24),
              if (account != null) ...[
                _FoundAccountCard(account: account),
                const SizedBox(height: 16),
                _EmailTargetCard(
                  maskedEmail: PasswordResetService.maskEmail(account.email),
                ),
                const SizedBox(height: 16),
                const _InfoBanner(
                  icon: Icons.shield_outlined,
                  message:
                      'Tautan hanya dikirim ke email resmi yang terdaftar pada '
                      'akun ini. Email ditampilkan dalam bentuk tersamarkan.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _sendLink,
                    child: _sending
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Text('Kirim Link Reset'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.go(AppRoutes.loginPath),
                  child: const Text('Kembali ke halaman Log In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundAccountCard extends StatelessWidget {
  const _FoundAccountCard({required this.account});

  final ResetAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.fullName.isEmpty
                      ? 'Akun ditemukan'
                      : account.fullName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Email terdaftar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green.shade600),
        ],
      ),
    );
  }
}

class _EmailTargetCard extends StatelessWidget {
  const _EmailTargetCard({required this.maskedEmail});

  final String maskedEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_read_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kirim ke Email',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  maskedEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.radio_button_checked, color: scheme.primary, size: 20),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
