import 'package:flutter/foundation.dart';

import '../models/admin_drafts.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';

/// Whether the signed-in member is church staff, and for which branch. The
/// app only uses this to show staff buttons; the database enforces the rules.
class StaffAccess extends ChangeNotifier {
  StaffAccess({this.source});

  /// Null when Supabase isn't set up.
  final AdminSource? source;

  StaffRole? role;

  /// The signed-in member's email (staff screens hide "remove" for it).
  String? email;
  int _generation = 0;
  bool _disposed = false;

  bool get isStaff => role != null;

  bool canManage(String? branchId) => role?.canManage(branchId) ?? false;

  /// Looks up [member]'s role; guests and members who aren't staff get none.
  Future<void> useMember(Member? member) async {
    final generation = ++_generation;
    role = null;
    email = member?.email;
    _changed();
    final source = this.source;
    if (source == null || member == null) return;
    try {
      final found = await source.myRole();
      if (_disposed || generation != _generation) return;
      role = found;
      _changed();
    } catch (_) {
      // Without the staff lookup the member simply sees no staff buttons.
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
