import 'package:ccc_app/models/admin_drafts.dart';
import 'package:ccc_app/models/stream_settings.dart';
import 'package:ccc_app/screens/admin/stream_settings_screen.dart';
import 'package:ccc_app/screens/main_screen.dart';
import 'package:ccc_app/services/church_query.dart';
import 'package:ccc_app/widgets/admin_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const settings = StreamSettings(id: 'b-botwe', name: 'CCC Botwe');
const existing = StreamSettings(
  id: 'b-botwe',
  name: 'CCC Botwe',
  handle: '@OldChurch',
);

Finder field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(LabeledField)),
  matching: find.byType(TextField),
);

class StreamAdmin extends FakeAdmin {
  StreamAdmin({super.role}) {
    streamBranches = [settings];
  }
  bool failSave = false;
  bool failLoad = false;

  @override
  Future<List<StreamSettings>> streamSettings() async {
    if (failLoad) throw const ChurchDataException('Settings could not load.');
    return super.streamSettings();
  }

  @override
  Future<void> saveStreamChannel(String branchId, String? channel) async {
    if (failSave) throw const ChurchDataException('Channel could not save.');
    await super.saveStreamChannel(branchId, channel);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'accepts channel links, tabs, handles and IDs; rejects video and spoofed links',
    () {
      final id = 'UC${List.filled(22, 'a').join()}';
      for (final input in [
        ' $id ',
        'https://www.youtube.com/channel/$id',
        'youtube.com/channel/$id/streams?si=123',
      ]) {
        expect(parseYouTubeChannel(input), id);
      }
      for (final input in [
        '@Church',
        'youtube.com/@Church',
        'https://m.youtube.com/@Church/live',
        'https://youtube.com/@Church/streams?si=123',
      ]) {
        expect(parseYouTubeChannel(input), '@Church');
      }
      for (final input in [
        '',
        '@',
        'UCwrong',
        '@has space',
        'https://youtube.com/watch?v=abc',
        'https://youtu.be/abc',
        'https://youtube.com.evil.test/@Church',
        'https://evil.test/@Church',
        'https://youtube.com@evil.test/@Church',
        'https://youtube.com:8080/@Church',
        'https://youtube.com/@Church/watch',
        'https://youtube.com/channel/@Church',
        'https://youtube.com/@Church%2Ffake',
      ]) {
        expect(parseYouTubeChannel(input), isNull, reason: input);
      }
    },
  );

  testWidgets(
    'media leaders find their channel settings in Account without staff access',
    (tester) async {
      final admin = StreamAdmin();
      final harness = Harness(admin: admin);
      await harness.pump(tester, const MainScreen(member: ama));
      await tester.tap(find.bySemanticsLabel('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Manage church content'), findsNothing);
      expect(find.text('Live stream settings'), findsOneWidget);
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CCC Botwe'));
      await tester.pumpAndSettle();
      expect(find.byType(StreamChannelEditor), findsOneWidget);
      expect(find.text('Manage media leaders'), findsNothing);
      await tester.enterText(
        field('YouTube channel'),
        'https://youtube.com/@MyChurch/streams?si=123',
      );
      await tester.tap(find.text('Save channel'));
      await tester.pumpAndSettle();
      expect(admin.savedChannels.single, (
        branchId: 'b-botwe',
        channel: '@MyChurch',
      ));
      expect(find.text('Channel saved.'), findsOneWidget);
      expect(
        find.text('Channel saved. Waiting for the automatic channel check.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('ordinary members do not see channel management', (tester) async {
    final harness = Harness(admin: FakeAdmin());
    await harness.pump(tester, const MainScreen(member: ama));
    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Live stream settings'), findsNothing);
  });

  testWidgets('failed saves preserve the input and a retry can succeed', (
    tester,
  ) async {
    final admin = StreamAdmin()..failSave = true;
    final harness = Harness(admin: admin);
    await harness.pump(tester, const StreamChannelEditor(settings: settings));
    await tester.enterText(field('YouTube channel'), '@MyChurch');
    await tester.tap(find.text('Save channel'));
    await tester.pumpAndSettle();
    expect(find.text('Channel could not save.'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('YouTube channel')).controller!.text,
      '@MyChurch',
    );
    expect(find.text('Channel saved.'), findsNothing);
    admin.failSave = false;
    await tester.tap(find.text('Save channel'));
    await tester.pumpAndSettle();
    expect(admin.savedChannels.single.channel, '@MyChurch');
  });

  testWidgets('video links are rejected without a backend write', (
    tester,
  ) async {
    final admin = StreamAdmin();
    final harness = Harness(admin: admin);
    await harness.pump(tester, const StreamChannelEditor(settings: settings));
    await tester.enterText(
      field('YouTube channel'),
      'https://youtube.com/watch?v=abc',
    );
    await tester.tap(find.text('Save channel'));
    await tester.pumpAndSettle();
    expect(admin.savedChannels, isEmpty);
    expect(find.textContaining('Video links cannot be used'), findsOneWidget);
  });

  testWidgets('changing and disconnecting a channel require confirmation', (
    tester,
  ) async {
    final admin = StreamAdmin();
    final harness = Harness(admin: admin);
    await harness.pump(tester, const StreamChannelEditor(settings: existing));
    await tester.enterText(field('YouTube channel'), '@NewChurch');
    await tester.tap(find.text('Save channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(admin.savedChannels, isEmpty);
    await tester.tap(find.text('Save channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change channel'));
    await tester.pumpAndSettle();
    expect(admin.savedChannels.single.channel, '@NewChurch');
    await tester.ensureVisible(find.text('Disconnect YouTube'));
    await tester.tap(find.text('Disconnect YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(admin.savedChannels.last.channel, isNull);
    expect(find.text('No YouTube channel connected.'), findsOneWidget);
  });

  testWidgets('staff appoint and remove media leaders from the app', (
    tester,
  ) async {
    final admin = StreamAdmin(role: const StaffRole(branchId: 'b-botwe'));
    final harness = Harness(admin: admin);
    await harness.state.staff.useMember(ama);
    await harness.pump(tester, const StreamChannelEditor(settings: settings));
    await tester.tap(find.text('Manage media leaders'));
    await tester.pumpAndSettle();
    await tester.enterText(
      field('Leader’s sign-in email'),
      ' Media@Church.org ',
    );
    await tester.tap(find.text('Add media leader'));
    await tester.pumpAndSettle();
    expect(admin.mediaLeadersByBranch['b-botwe'], ['media@church.org']);
    expect(find.text('media@church.org'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove media@church.org'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(admin.mediaLeadersByBranch['b-botwe'], isEmpty);
  });

  testWidgets(
    'load failures offer retry and a successful refresh shows allowed branches',
    (tester) async {
      final admin = StreamAdmin()..failLoad = true;
      final harness = Harness(admin: admin);
      await harness.pump(tester, const StreamSettingsScreen());
      expect(find.text('Settings could not load.'), findsOneWidget);
      admin.failLoad = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('CCC Botwe'), findsOneWidget);
    },
  );

  test('signing out clears media leader permissions', () async {
    final harness = Harness(admin: StreamAdmin());
    await harness.state.staff.useMember(ama);
    expect(harness.state.staff.canManageStreams, isTrue);
    await harness.state.staff.useMember(null);
    expect(harness.state.staff.canManageStreams, isFalse);
  });
}
