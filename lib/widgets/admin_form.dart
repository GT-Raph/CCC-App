import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/church_branch.dart';
import '../models/event.dart' show eventDateLabel;
import '../theme/ccc_theme.dart';
import 'ccc_widgets.dart';

/// A staff form screen: the back button and title, the fields, and Save
/// (plus Delete for existing items) at the bottom. Leaving with unsaved
/// changes asks first.
class AdminFormScaffold extends StatelessWidget {
  const AdminFormScaffold({
    required this.title,
    required this.children,
    required this.saveLabel,
    required this.onSave,
    this.onDelete,
    this.deleteLabel = 'Delete',
    this.busy = false,
    this.busyLabel,
    this.dirty = false,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final String saveLabel;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final String deleteLabel;

  /// Saving or uploading: the buttons wait.
  final bool busy;

  /// Shown under the button while busy, e.g. "Uploading the recording…".
  final String? busyLabel;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !dirty || busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmAction(
          context,
          title: 'Discard your changes?',
          message: "What you've entered here won't be saved.",
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            DetailsHeader(title: title),
            Expanded(
              child: AbsorbPointer(
                absorbing: busy,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
                  children: [
                    ...children,
                    const SizedBox(height: 20),
                    CccButton(
                      label: saveLabel,
                      isLoading: busy,
                      onPressed: onSave,
                    ),
                    if (busy && busyLabel != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        busyLabel!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: p.textMuted),
                      ),
                    ],
                    if (onDelete != null) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: busy ? null : onDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: p.error,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            deleteLabel,
                            style: const TextStyle(
                              fontFamily: CccFonts.openSans,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before something that can't be undone. True if confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final p = context.palette;
  const buttonText = TextStyle(
    fontFamily: CccFonts.openSans,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          style: TextButton.styleFrom(
            foregroundColor: p.textSecondary,
            textStyle: buttonText,
          ),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? p.error : p.accentText,
            textStyle: buttonText,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A group of fields under a small heading.
class FormSection extends StatelessWidget {
  const FormSection({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: SectionTitle(title),
          ),
          for (final child in children) ...[child, const SizedBox(height: 16)],
        ],
      ),
    );
  }
}

/// A text field with its label above it, a hint below it, and room for an
/// error message.
class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.error,
    this.required = false,
    this.lines = 1,
    this.keyboardType,
    this.capitalization = TextCapitalization.sentences,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? error;
  final bool required;
  final int lines;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, required: required),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: lines,
          maxLines: lines == 1 ? 1 : null,
          keyboardType: lines > 1 ? TextInputType.multiline : keyboardType,
          textCapitalization: capitalization,
          onChanged: onChanged,
          style: TextStyle(fontSize: 16, color: context.palette.text),
          decoration: cccFieldDecoration(
            context,
            hint: hint,
            helper: helper,
            error: error,
          ),
        ),
      ],
    );
  }
}

/// The box tapped to open a picker (branch, date, file), styled like a
/// field.
class PickerBox extends StatelessWidget {
  const PickerBox({
    required this.text,
    required this.icon,
    this.onTap,
    this.placeholder = false,
    this.error,
    this.trailing,
    super.key,
  });

  final String text;
  final IconData icon;

  /// Null shows the box as fixed (e.g. a branch staff member's own branch).
  final VoidCallback? onTap;
  final bool placeholder;
  final String? error;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final borderColor = error != null ? p.error : p.lineStrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: onTap == null ? p.surfaceAlt : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: onTap == null ? p.line : borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: p.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 16,
                          color: placeholder ? p.textMuted : p.text,
                        ),
                      ),
                    ),
                    ?trailing,
                    if (onTap != null && trailing == null)
                      Icon(Icons.expand_more, color: p.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(error!, style: TextStyle(fontSize: 13, color: p.error)),
          ),
      ],
    );
  }
}

/// Picks the branch an item belongs to. Branch staff only ever see their
/// own branch; HQ admins choose any, and "All branches" where
/// [allBranchesLabel] is given.
class BranchChooser extends StatelessWidget {
  const BranchChooser({
    required this.label,
    required this.branches,
    required this.value,
    required this.onChanged,
    required this.lockedTo,
    this.allBranchesLabel,
    this.error,
    super.key,
  });

  final String label;
  final List<ChurchBranch> branches;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// The staff member's own branch when they're branch staff.
  final String? lockedTo;

  /// Offered (as an empty branch) to HQ admins, e.g. "All branches".
  final String? allBranchesLabel;
  final String? error;

  String _name(String? id) {
    if (id == null) return allBranchesLabel ?? 'Choose a branch';
    for (final branch in branches) {
      if (branch.id == id) return branch.name;
    }
    return 'This branch';
  }

  Future<void> _choose(BuildContext context) async {
    final options = <(String?, String)>[
      if (allBranchesLabel != null) (null, allBranchesLabel!),
      for (final branch in branches) (branch.id, branch.name),
    ];
    final chosen = await showModalBottomSheet<(String?,)>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: p.text,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (id, name) in options)
                        ListTile(
                          minTileHeight: 52,
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: id == value
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: p.text,
                            ),
                          ),
                          trailing: id == value
                              ? const Icon(
                                  Icons.check_circle,
                                  color: CccColors.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(sheetContext, (id,)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) onChanged(chosen.$1);
  }

  @override
  Widget build(BuildContext context) {
    final locked = lockedTo != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, required: allBranchesLabel == null),
        const SizedBox(height: 6),
        PickerBox(
          icon: Icons.church_outlined,
          text: _name(locked ? lockedTo : value),
          placeholder: !locked && value == null && allBranchesLabel == null,
          error: error,
          onTap: locked ? null : () => _choose(context),
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              'Branch staff post for their own branch.',
              style: TextStyle(fontSize: 13, color: context.palette.textMuted),
            ),
          ),
      ],
    );
  }
}

/// A date (and optionally time) chosen with the platform pickers.
class DateTimeChooser extends StatelessWidget {
  const DateTimeChooser({
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = true,
    this.required = true,
    this.placeholder = 'Not set',
    this.helper,
    this.error,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool withTime;
  final bool required;
  final String placeholder;
  final String? helper;
  final String? error;

  Future<void> _choose(BuildContext context) async {
    final now = DateTime.now();
    final start = value ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (day == null || !context.mounted) return;
    if (!withTime) {
      onChanged(DateTime(day.year, day.month, day.day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null) return;
    onChanged(DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  String _label(DateTime time) {
    if (withTime) return eventDateLabel(time);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${time.day} ${months[time.month - 1]} ${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value = this.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, required: required),
        const SizedBox(height: 6),
        PickerBox(
          icon: withTime ? Icons.schedule : Icons.calendar_today_outlined,
          text: value == null ? placeholder : _label(value),
          placeholder: value == null,
          error: error,
          onTap: () => _choose(context),
          trailing: !required && value != null
              ? IconButton(
                  tooltip: 'Clear $label',
                  onPressed: () => onChanged(null),
                  icon: Icon(Icons.close, color: p.textMuted),
                )
              : null,
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              helper!,
              style: TextStyle(fontSize: 13, color: p.textMuted),
            ),
          ),
      ],
    );
  }
}

/// A photo already uploaded ([path]) or newly picked ([bytes]).
class PhotoItem {
  PhotoItem.stored(String this.path, this.url) : bytes = null, name = null;
  PhotoItem.picked(Uint8List this.bytes, String this.name)
    : path = null,
      url = null;

  final String? path;
  final String? url;
  final Uint8List? bytes;
  final String? name;

  bool get isNew => bytes != null;
}

/// Photos for an item: thumbnails with a remove button, and Add photos.
class PhotoChooser extends StatelessWidget {
  const PhotoChooser({
    required this.photos,
    required this.onChanged,
    this.max = 6,
    super.key,
  });

  final List<PhotoItem> photos;
  final ValueChanged<List<PhotoItem>> onChanged;
  final int max;

  Future<void> _add(BuildContext context) async {
    final picked = await ImagePicker().pickMultiImage(
      // Large enough for any phone screen, small enough to upload quickly.
      maxWidth: 1600,
      imageQuality: 82,
      limit: max - photos.length,
    );
    if (picked.isEmpty) return;
    final added = [
      for (final file in picked.take(max - photos.length))
        PhotoItem.picked(await file.readAsBytes(), file.name),
    ];
    onChanged([...photos, ...added]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (index, photo) in photos.indexed)
              _Thumbnail(
                photo: photo,
                first: index == 0,
                onRemove: () => onChanged([...photos]..removeAt(index)),
              ),
            if (photos.length < max)
              Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: p.lineStrong),
                ),
                child: InkWell(
                  onTap: () => _add(context),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 96,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: p.accentText,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add photos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'The first photo leads the card. Up to $max.',
          style: TextStyle(fontSize: 13, color: p.textMuted),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.photo,
    required this.first,
    required this.onRemove,
  });

  final PhotoItem photo;
  final bool first;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final image = photo.isNew
        ? Image.memory(photo.bytes!, fit: BoxFit.cover)
        : Image.network(
            photo.url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: p.surfaceAlt,
              child: Icon(Icons.broken_image_outlined, color: p.textMuted),
            ),
          );
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
          if (first)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CccColors.primary,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'Cover',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CccColors.onPrimary,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              tooltip: 'Remove photo',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                backgroundColor: p.surface,
                side: BorderSide(color: p.line),
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
              icon: Icon(Icons.close, size: 18, color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled on/off setting.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeTrackColor: CccColors.primary,
        activeThumbColor: CccColors.onPrimary,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(fontSize: 13, color: p.textSecondary),
              ),
      ),
    );
  }
}

/// The content type for a picked photo, from its file name.
String imageContentType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}
