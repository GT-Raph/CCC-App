import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/church_branch.dart';

/// The signed-in member, as much as the screens need to know about them.
class Member {
  const Member({required this.firstName, required this.email, this.branch});

  factory Member.fromUser(User user) {
    final metadata = user.userMetadata ?? const {};
    final email = user.email ?? '';
    final firstName = _firstNonEmpty([
      metadata['first_name'],
      (metadata['full_name'] as String?)?.split(' ').first,
      (metadata['name'] as String?)?.split(' ').first,
      email.split('@').first,
    ]);
    final branchId = metadata['branch_id'];
    final branchName = metadata['branch_name'];
    return Member(
      firstName: firstName ?? 'Member',
      email: email,
      branch: branchId is String && branchName is String
          ? ChurchBranch(id: branchId, name: branchName)
          : null,
    );
  }

  final String firstName;
  final String email;

  /// The branch the member attends; their sermons come from it. Null for
  /// members who signed up before branches existed or with Google, Facebook
  /// or Apple, until they choose one.
  final ChurchBranch? branch;
}

String? _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Thin wrapper over Supabase Auth so screens never touch the client directly.
class AuthService {
  /// Deep link Supabase redirects to after Google, Facebook or Apple sign-in.
  /// It must also be listed under Auth → URL Configuration in Supabase.
  static const oauthRedirect = 'io.supabase.cccapp://login-callback/';

  /// The social sign-in buttons to show: only providers switched on in
  /// Supabase, listed in .env as SOCIAL_SIGN_IN (e.g. "google,apple").
  static List<OAuthProvider> socialProviders = const [];

  static List<OAuthProvider> parseProviders(String? setting) {
    const known = {
      'facebook': OAuthProvider.facebook,
      'google': OAuthProvider.google,
      'apple': OAuthProvider.apple,
    };
    return [
      for (final name in (setting ?? '').toLowerCase().split(','))
        ?known[name.trim()],
    ];
  }

  static bool get isConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  static Member? get currentMember {
    if (!isConfigured) return null;
    final user = _auth.currentUser;
    return user == null ? null : Member.fromUser(user);
  }

  static Future<Member> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    return Member.fromUser(response.user!);
  }

  /// Returns the new member when Supabase signs them straight in, or null
  /// when the project requires them to confirm their email first.
  static Future<Member?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required ChurchBranch branch,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'full_name': '$firstName $lastName',
        ..._branchData(branch),
      },
    );
    if (response.session == null || response.user == null) return null;
    return Member.fromUser(response.user!);
  }

  /// Saves the member's branch on their account (and, through the database
  /// trigger, on their profile).
  static Future<void> updateBranch(ChurchBranch branch) async {
    await _auth.updateUser(UserAttributes(data: _branchData(branch)));
  }

  static Map<String, Object?> _branchData(ChurchBranch branch) => {
    'branch_id': branch.id,
    'branch_name': branch.name,
  };

  static Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email);

  static Future<void> signInWithProvider(OAuthProvider provider) async {
    await _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : oauthRedirect,
    );
  }

  /// Emits the member each time someone finishes signing in (used for the
  /// browser-based social sign-in, which completes outside the app).
  static Stream<Member> get signIns => _auth.onAuthStateChange
      .where(
        (state) =>
            state.event == AuthChangeEvent.signedIn &&
            state.session?.user != null,
      )
      .map((state) => Member.fromUser(state.session!.user));

  static Future<void> signOut() => _auth.signOut();
}
