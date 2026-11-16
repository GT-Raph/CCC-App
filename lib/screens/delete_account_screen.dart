import 'package:flutter/material.dart';

import '../navigation.dart';
import '../services/auth_service.dart';
import '../services/church_query.dart';
import '../state/ccc_state.dart';
import '../theme/ccc_theme.dart';
import '../widgets/admin_form.dart';
import '../widgets/ccc_widgets.dart';

/// Deletes the member's account, as the app stores require: what goes, what
/// stays, then one confirmation.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    this.deleteAccount = AuthService.deleteAccount,
    super.key,
  });

  /// Replaced in tests.
  final Future<void> Function() deleteAccount;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete your account?',
      message:
          "This can't be undone. To use the app as a member again, you'll "
          'need to create a new account.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.deleteAccount();
      if (!mounted) return;
      await CccScope.of(context).forgetMember();
      if (!mounted) return;
      showCccMessage(context, 'Your account has been deleted.');
      CccNavigation.openWelcome(context);
    } on ChurchDataException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              "Your account couldn't be deleted. Check your internet "
              'connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final side = readableGutter(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final body = TextStyle(fontSize: 15.5, height: 1.5, color: p.text);
    // Readable on the red in both themes.
    final onError = p.isDark ? p.background : Colors.white;
    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(title: 'Delete account'),
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: EdgeInsets.fromLTRB(side, 8, side, 24 + bottom),
                children: [
                  Text(
                    'Deleting your account removes it and your details from '
                    'the app for good.',
                    style: body,
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('What’s deleted'),
                  const SizedBox(height: 10),
                  const _Point('Your name, email address and branch'),
                  const _Point(
                    'The details you gave about yourself: date of birth, '
                    'gender, marital status and whether you’re a student',
                  ),
                  const _Point('Your ministry memberships and requests to join'),
                  const _Point(
                    'Any staff, ministry leader or media leader role you have',
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle('What stays'),
                  const SizedBox(height: 10),
                  const _Point(
                    'News, events, sermons and photos you posted for the '
                    'church. They belong to the church, and its staff can '
                    'remove them.',
                  ),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(fontSize: 14, color: p.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _delete,
                      style: FilledButton.styleFrom(
                        backgroundColor: p.error,
                        foregroundColor: onError,
                        disabledBackgroundColor: p.error,
                        disabledForegroundColor: onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: CccFonts.openSans,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _busy
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: onError,
                              ),
                            )
                          : const Text('Delete account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.textMuted,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 5),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
