import 'package:ccc_app/screens/delete_account_screen.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/screens/set_new_password_screen.dart';
import 'package:ccc_app/screens/welcome_screen.dart';
import 'package:ccc_app/services/church_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'support/fakes.dart';

Finder dialogButton(String label) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text(label),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('deleting an account', () {
    testWidgets('is offered from the account sheet, apart from Sign out', (
      tester,
    ) async {
      await Harness().pump(tester, const MainScreen(member: ama));
      await tester.tap(find.bySemanticsLabel('Account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete account'));
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text('What’s deleted'), findsOneWidget);
    });

    testWidgets('asks first, then deletes, signs out and says so', (
      tester,
    ) async {
      var deleted = 0;
      final harness = Harness();
      await harness.state.ministries.useMember(ama);
      await harness.pump(
        tester,
        DeleteAccountScreen(deleteAccount: () async => deleted++),
      );

      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Cancel'));
      await tester.pumpAndSettle();
      expect(deleted, 0);

      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Delete account'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Your account has been deleted.'), findsOneWidget);
    });

    testWidgets('a refusal is shown and the member stays', (tester) async {
      await Harness().pump(
        tester,
        DeleteAccountScreen(
          deleteAccount: () async => throw const ChurchDataException(
            'You are the church’s only super admin.',
          ),
        ),
      );
      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('You are the church’s only super admin.'), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });
  });

  group('choosing a new password after a reset link', () {
    testWidgets('checks the two entries match before saving', (tester) async {
      final saved = <String>[];
      await Harness().pump(
        tester,
        SetNewPasswordScreen(savePassword: (password) async => saved.add(password)),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'grace2026');
      await tester.enterText(fields.at(1), 'grace2025');
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);

      await tester.enterText(fields.at(1), 'grace2026');
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(saved, ['grace2026']);
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Password changed.'), findsOneWidget);
      // Without Supabase there's no member, so Home invites a guest to log
      // in after a second; let that timer finish.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets("Supabase's refusal is shown and nothing moves on", (
      tester,
    ) async {
      await Harness().pump(
        tester,
        SetNewPasswordScreen(
          savePassword: (_) async => throw const AuthException(
            'New password should be different from the old password.',
          ),
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'grace2026');
      await tester.enterText(fields.at(1), 'grace2026');
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(
        find.text('New password should be different from the old password.'),
        findsOneWidget,
      );
      expect(find.byType(SetNewPasswordScreen), findsOneWidget);
    });

    testWidgets('Cancel leaves for the welcome screen', (tester) async {
      await Harness().pump(tester, const SetNewPasswordScreen());
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}
