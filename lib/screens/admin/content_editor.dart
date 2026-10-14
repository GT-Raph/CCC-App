import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_drafts.dart';
import '../../models/church_branch.dart';
import '../../services/admin_service.dart';
import '../../services/church_query.dart';
import '../../state/ccc_state.dart';
import '../../widgets/admin_form.dart';
import '../../widgets/ccc_widgets.dart';

/// What happened in an editor, for the screen that opened it.
enum EditorResult { saved, deleted }

/// Loading, saving and deleting shared by the four content editors.
mixin ContentEditor<W extends StatefulWidget> on State<W> {
  ContentKind get kind;

  /// The item being edited; null for a new one.
  String? get editingId;

  bool busy = false;
  bool dirty = false;
  bool loading = false;
  String? loadError;

  CccState get app => CccScope.of(context);
  AdminSource get admin => app.staff.source!;
  StaffRole get role => app.staff.role ?? const StaffRole(branchId: '-');

  /// The branches staff can pick from, loaded for the branch chooser.
  List<ChurchBranch> get branches => app.sermons.branchList;

  /// The staff member's own branch when they're branch staff.
  String? get lockedBranch => role.churchWide ? null : role.branchId;

  void markDirty() {
    if (!dirty) setState(() => dirty = true);
  }

  /// Fills the form from the saved row (editing) or defaults (new).
  void fill(Map<String, dynamic>? row);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    unawaited(app.sermons.loadBranches());
    final id = editingId;
    if (id == null) {
      setState(() => fill(null));
      return;
    }
    setState(() => loading = true);
    try {
      final row = await admin.row(kind, id);
      if (!mounted) return;
      setState(() {
        loading = false;
        if (row == null) {
          loadError = 'This ${kind.noun} no longer exists.';
        } else {
          fill(row);
        }
      });
    } on ChurchDataException catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = error.message;
        });
      }
    }
  }

  /// Uploads newly picked photos; returns every photo's stored path in order.
  Future<List<String>> storePhotos(List<PhotoItem> photos) async {
    final paths = <String>[];
    for (final photo in photos) {
      paths.add(
        photo.isNew
            ? await admin.upload(
                kind.bucket,
                photo.name!,
                photo.bytes!,
                imageContentType(photo.name!),
              )
            : photo.path!,
      );
    }
    return paths;
  }

  List<PhotoItem> storedPhotos(List<String> paths) => [
    for (final path in paths)
      PhotoItem.stored(path, admin.publicUrl(kind.bucket, path)),
  ];

  /// Runs [save], then refreshes what members see and closes the editor.
  /// [removedFiles] are cleaned up only once the save succeeded.
  Future<void> commit(
    Future<void> Function() save, {
    required String done,
    List<String> removedFiles = const [],
  }) async {
    setState(() => busy = true);
    try {
      await save();
      await admin.removeFiles(kind.bucket, removedFiles);
      _refreshFeed();
      if (!mounted) return;
      dirty = false;
      showCccMessage(context, done);
      Navigator.of(context).pop(EditorResult.saved);
    } on ChurchDataException catch (error) {
      if (mounted) showCccMessage(context, error.message);
    } catch (_) {
      if (mounted) {
        showCccMessage(context, "Couldn't save. Try again in a moment.");
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Asks, then deletes the item and its files.
  Future<void> remove({
    required String name,
    List<String> files = const [],
  }) async {
    final id = editingId;
    if (id == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this ${kind.noun}?',
      message:
          '“$name” will be removed from the app for everyone. This '
          "can't be undone.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => busy = true);
    try {
      await admin.delete(kind, id);
      await admin.removeFiles(kind.bucket, files);
      _refreshFeed();
      if (!mounted) return;
      dirty = false;
      showCccMessage(context, 'Deleted.');
      Navigator.of(context).pop(EditorResult.deleted);
    } on ChurchDataException catch (error) {
      if (mounted) showCccMessage(context, error.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _refreshFeed() {
    final app = this.app;
    unawaited(switch (kind) {
      ContentKind.news => app.news.refresh(),
      ContentKind.events => app.events.refresh(),
      ContentKind.sermons => app.sermons.refresh(),
      ContentKind.ministries => app.ministries.refresh(),
    });
  }

  /// The form, or loading / not-found states while editing.
  List<Widget> body(List<Widget> Function() form) {
    if (loading) {
      return const [SkeletonList(label: 'Loading', count: 2)];
    }
    if (loadError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ];
    }
    return form();
  }
}
