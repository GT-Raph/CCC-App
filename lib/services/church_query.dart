import 'package:supabase_flutter/supabase_flutter.dart';

/// A Supabase read or write that failed, in words the app can show.
class ChurchDataException implements Exception {
  const ChurchDataException(this.message, {this.setupMissing = false});

  final String message;

  /// The table or column doesn't exist yet: `supabase/schema.sql` hasn't
  /// been run (or re-run after an update).
  final bool setupMissing;

  @override
  String toString() => message;
}

/// Runs a Supabase query for [what] ("Sermons", "Events"), turning failures
/// into a [ChurchDataException]. [saving] words failures as a save that
/// didn't happen rather than a list that didn't load.
Future<List<Map<String, dynamic>>> churchQuery(
  String what,
  Future<List<Map<String, dynamic>>> Function() run, {
  bool saving = false,
}) async {
  try {
    return await run();
  } on PostgrestException catch (error) {
    // PGRST205 / 42P01: no such table. 42703: no such column.
    final missing = const {'PGRST205', '42P01', '42703'}.contains(error.code);
    throw ChurchDataException(switch (error.code) {
      _ when missing => '$what are not set up yet.',
      // Row-level security refused it (supabase/staff.sql).
      '42501' => "You don't have permission to do that.",
      // A required field is empty or a value isn't allowed.
      '23502' || '23514' => 'Some details are missing or not valid.',
      _ when saving => "Couldn't save. Try again in a moment.",
      _ => "$what couldn't load. Try again in a moment.",
    }, setupMissing: missing);
  } catch (_) {
    throw ChurchDataException(
      saving
          ? "Couldn't save. Check your internet connection and try again."
          : "$what couldn't load. Check your internet connection and try "
                'again.',
    );
  }
}
