import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../navigation.dart';
import '../services/auth_service.dart';
import '../theme/ccc_theme.dart';
import '../widgets/ccc_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (!email.contains('@') || password.length < 6) {
      showCccMessage(
        context,
        'Enter a valid email and a password with at least 6 characters.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isSubmitting = true);
    try {
      final member = await AuthService.signIn(email: email, password: password);
      if (mounted) CccNavigation.openMain(context, member: member);
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

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();
    if (!email.contains('@')) {
      showCccMessage(context, 'Enter your email address first.');
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) {
        showCccMessage(context, 'Password reset instructions sent to $email.');
      }
    } on AuthException catch (error) {
      if (mounted) showCccMessage(context, error.message);
    } catch (_) {
      if (mounted) showCccMessage(context, 'Unable to send a reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AutofillGroup(
        child: FullScreenColumn(
          topGap: 8,
          bottomGap: 8,
          children: [
            const AuthBackButton(),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: ChurchLogo(width: 52),
            ),
            const SizedBox(height: 24),
            const AuthTitle(
              title: 'Welcome back',
              subtitle:
                  "Log in to hear your branch's sermons and keep up with its "
                  'events.',
            ),
            const SizedBox(height: 28),
            AuthField(
              label: 'Email',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Password',
              controller: passwordController,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: p.accentText,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(
                    fontFamily: CccFonts.openSans,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 12),
            CccButton(
              label: 'Log in',
              onPressed: _submit,
              isLoading: isSubmitting,
            ),
            const Spacer(),
            const SizedBox(height: 24),
            AuthFooterLink(
              prompt: 'New here?',
              action: 'Create account',
              onTap: () => CccNavigation.openSignUp(context, replace: true),
            ),
          ],
        ),
      ),
    );
  }
}
