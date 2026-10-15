import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/church_branch.dart';
import '../state/ccc_state.dart';
import '../state/sermon_library.dart';
import '../theme/ccc_theme.dart';
import 'ccc_widgets.dart';

/// Bottom sheet listing the church's branches. Returns the branch tapped, or
/// null if the sheet is dismissed.
Future<ChurchBranch?> showBranchPicker(
  BuildContext context, {
  ChurchBranch? selected,
  String title = 'Choose your branch',
  String? message,
}) {
  final library = CccScope.of(context).sermons..loadBranches();
  return showModalBottomSheet<ChurchBranch>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BranchPickerSheet(
      library: library,
      selected: selected,
      title: title,
      message: message,
    ),
  );
}

class _BranchPickerSheet extends StatefulWidget {
  const _BranchPickerSheet({
    required this.library,
    required this.selected,
    required this.title,
    required this.message,
  });

  final SermonLibrary library;
  final ChurchBranch? selected;
  final String title;
  final String? message;

  @override
  State<_BranchPickerSheet> createState() => _BranchPickerSheetState();
}

class _BranchPickerSheetState extends State<_BranchPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: ListenableBuilder(
              listenable: widget.library,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.3,
                      color: p.text,
                    ),
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.message!,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ..._content(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    final library = widget.library;
    if (!library.isConfigured) {
      return const [_PickerNotice('Branches are not available yet.')];
    }
    switch (library.branchListStatus) {
      case BranchListStatus.idle:
      case BranchListStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case BranchListStatus.failed:
        return [
          _PickerNotice(
            library.branchListError!,
            detail: kDebugMode && library.setupMissing
                ? 'Run supabase/schema.sql and supabase/branches.sql in '
                      'Supabase (see README).'
                : null,
          ),
          Center(
            child: CccButton(
              label: 'Try again',
              variant: CccButtonVariant.outlined,
              width: 160,
              height: 44,
              fontSize: 14,
              onPressed: () => library.loadBranches(force: true),
            ),
          ),
          const SizedBox(height: 16),
        ];
      case BranchListStatus.ready:
        break;
    }
    final all = library.branchList;
    if (all.isEmpty) {
      return const [_PickerNotice('No branches have been added yet.')];
    }
    final shown = all.where((branch) => branch.matches(query)).toList();
    return [
      if (all.length > 6) ...[
        _PickerSearch(onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 8),
      ],
      Flexible(
        child: shown.isEmpty
            ? _PickerNotice('Nothing matches “$query”.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: shown.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _BranchRow(
                  branch: shown[index],
                  selected: shown[index] == widget.selected,
                  onTap: () => Navigator.pop(context, shown[index]),
                ),
              ),
      ),
    ];
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  final ChurchBranch branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Icon(
                Icons.church_outlined,
                size: 20,
                color: selected ? p.accentText : p.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    branch.name,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: p.text,
                    ),
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.check_circle,
                  size: 22,
                  color: CccColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSearch extends StatelessWidget {
  const _PickerSearch({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 16, color: p.text),
      decoration: cccFieldDecoration(context, hint: 'Search branches').copyWith(
        prefixIcon: Icon(Icons.search, size: 20, color: p.textMuted),
        fillColor: p.surfaceAlt,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PickerNotice extends StatelessWidget {
  const _PickerNotice(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: p.textSecondary),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Your branch" on the sign up form, styled like the text fields.
class BranchPickerField extends StatelessWidget {
  const BranchPickerField({
    required this.branch,
    required this.onChanged,
    super.key,
  });

  final ChurchBranch? branch;
  final ValueChanged<ChurchBranch> onChanged;

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final chosen = await showBranchPicker(
      context,
      selected: branch,
      message: 'Sermons in the app come from your branch.',
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final branch = this.branch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Your branch'),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: branch == null
              ? 'Choose your branch'
              : 'Branch, ${branch.name}',
          excludeSemantics: true,
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: p.lineStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _pick(context),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.church_outlined, size: 20, color: p.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        branch?.name ?? 'Select a branch',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: branch == null ? p.textMuted : p.text,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more, size: 22, color: p.textMuted),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
