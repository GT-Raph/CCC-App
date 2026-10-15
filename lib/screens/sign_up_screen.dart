import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../models/church_branch.dart';
import '../navigation.dart';
import '../services/auth_service.dart';
import '../widgets/branch_picker.dart';
import '../widgets/ccc_widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  ChurchBranch? branch;
  bool isSubmitting = false;

  @override
  void dispose() {
    for (final controller in [
      firstNameController,
      lastNameController,
      emailController,
      passwordController,
      confirmController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    final problem = firstName.isEmpty || lastName.isEmpty
        ? 'Enter your first and last name.'
        : !email.contains('@')
        ? 'Enter a valid email address.'
        : password.length < 6
        ? 'Use a password with at least 6 characters.'
        : password != confirmController.text
        ? 'The passwords do not match.'
        : branch == null
        ? 'Choose your branch.'
        : null;
    if (problem != null) {
      showCccMessage(context, problem);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isSubmitting = true);
    try {
      final member = await AuthService.signUp(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        branch: branch!,
      );
      if (!mounted) return;
      if (member != null) {
        CccNavigation.openMain(context, member: member);
      } else {
        showCccMessage(
          context,
          'Account created. Check your email to confirm it, then log in.',
        );
        CccNavigation.openLogin(context, replace: true);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AutofillGroup(
        child: FullScreenColumn(
          topGap: 8,
          bottomGap: 8,
          children: [
            const AuthBackButton(),
            const SizedBox(height: 16),
            const AuthTitle(
              title: 'Create your account',
              subtitle:
                  'Choose your branch to get its sermons, events and live '
                  'services.',
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AuthField(
                    label: 'First name',
                    controller: firstNameController,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    label: 'Last name',
                    controller: lastNameController,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.familyName],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Confirm password',
              controller: confirmController,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            BranchPickerField(
              branch: branch,
              onChanged: (value) => setState(() => branch = value),
            ),
            const SizedBox(height: 28),
            CccButton(
              label: 'Create account',
              onPressed: _submit,
              isLoading: isSubmitting,
            ),
            const Spacer(),
            const SizedBox(height: 16),
            AuthFooterLink(
              prompt: 'Have an account?',
              action: 'Log in',
              onTap: () => CccNavigation.openLogin(context, replace: true),
            ),
          ],
        ),
      ),
    );
  }
}
