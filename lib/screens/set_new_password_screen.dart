import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../navigation.dart';
import '../services/auth_service.dart';
import '../state/ccc_state.dart';
import '../theme/ccc_theme.dart';
import '../widgets/ccc_widgets.dart';

/// Opened by a password reset link. Supabase has already signed the member
/// in for it; they choose a new password, then carry on into the app.
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({
    this.savePassword = AuthService.updatePassword,
    super.key,
  });

  /// Replaced in tests.
  final Future<void> Function(String password) savePassword;

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool isSubmitting = false;

  String? get passwordMismatch {
    final password = passwordController.text;
    final confirmation = confirmController.text;
    if (password.isEmpty || confirmation.isEmpty || password == confirmation) {
      return null;
    }
    return 'Passwords do not match.';
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = passwordController.text;
    final problem = password.length < 6
        ? 'Use a password with at least 6 characters.'
        : password != confirmController.text
        ? 'The passwords do not match.'
        : null;
    if (problem != null) {
      showCccMessage(context, problem);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isSubmitting = true);
    try {
      await widget.savePassword(password);
      if (!mounted) return;
      showCccMessage(context, 'Password changed.');
      CccNavigation.openMain(context, member: AuthService.currentMember);
    } on AuthException catch (error) {
      if (mounted) showCccMessage(context, error.message);
    } catch (_) {
      if (mounted) {
        showCccMessage(
          context,
          'Unable to connect. Check your internet connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  /// Leaves without a new password: the reset link's sign-in is undone.
  Future<void> _cancel() async {
    final state = CccScope.of(context);
    if (AuthService.isConfigured) await AuthService.signOut();
    await state.forgetMember();
    if (mounted) CccNavigation.openWelcome(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final email = AuthService.currentMember?.email;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AutofillGroup(
        child: FullScreenColumn(
          topGap: 8,
          bottomGap: 8,
          children: [
            const SizedBox(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: ChurchLogo(height: 76),
            ),
            const SizedBox(height: 24),
            AuthTitle(
              title: 'Choose a new password',
              subtitle: email == null || email.isEmpty
                  ? 'You’ll use it the next time you log in.'
                  : 'For $email. You’ll use it the next time you log in.',
            ),
            const SizedBox(height: 28),
            AuthField(
              label: 'New password',
              controller: passwordController,
              isPassword: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Confirm new password',
              controller: confirmController,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              error: passwordMismatch,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 28),
            CccButton(
              label: 'Save password',
              onPressed: _submit,
              isLoading: isSubmitting,
            ),
            const Spacer(),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: isSubmitting ? null : _cancel,
                style: TextButton.styleFrom(
                  foregroundColor: p.textSecondary,
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontFamily: CccFonts.openSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
