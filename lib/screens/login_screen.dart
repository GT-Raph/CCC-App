import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: PhotoBackground(
          child: AutofillGroup(
            child: FullScreenColumn(
              bottomGap: 14,
              children: [
                const SizedBox(height: 60),
                const ChurchLogo(width: 117, color: CccColors.paper),
                const Spacer(flex: 110),
                const AuthTitle(
                  title: 'Welcome Back',
                  subtitle:
                      "Log in to hear your branch's sermons and keep up with "
                      'its events.',
                ),
                const Spacer(flex: 105),
                AuthField(
                  icon: FieldIcons.email,
                  hint: 'Email',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 30),
                AuthField(
                  icon: FieldIcons.key,
                  hint: 'Password',
                  controller: passwordController,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 17 / 14,
                        color: CccColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                CccButton(
                  label: 'Login',
                  onPressed: _submit,
                  isLoading: isSubmitting,
                ),
                const Spacer(flex: 60),
                AuthFooterLink(
                  prompt: "Don't have an account?",
                  action: 'Sign Up',
                  onTap: () => CccNavigation.openSignUp(context, replace: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
