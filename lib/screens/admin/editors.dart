import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/admin_drafts.dart';
import '../../theme/ccc_theme.dart';
import '../../widgets/admin_form.dart';
import '../../widgets/ccc_widgets.dart';
import 'admin_lists.dart';
import 'content_editor.dart';

/// Writes or edits a news story.
class NewsEditor extends StatefulWidget {
  const NewsEditor({this.id, super.key});

  final String? id;

  @override
  State<NewsEditor> createState() => _NewsEditorState();
}

class _NewsEditorState extends State<NewsEditor>
    with ContentEditor<NewsEditor> {
  @override
  ContentKind get kind => ContentKind.news;
  @override
  String? get editingId => widget.id;

  final title = TextEditingController();
  final subtitle = TextEditingController();
  final summary = TextEditingController();
  final story = TextEditingController();
  String? branchId;
  DateTime publishedAt = DateTime.now();
  List<PhotoItem> photos = [];
  List<String> savedPaths = [];
  String? titleError;

  @override
  void fill(Map<String, dynamic>? row) {
    if (row == null) {
      branchId = lockedBranch;
      return;
    }
    final draft = NewsDraft.fromRow(row);
    title.text = draft.title;
    subtitle.text = draft.subtitle;
    summary.text = draft.summary;
    story.text = draft.body;
    branchId = draft.branchId;
    publishedAt = draft.publishedAt;
    savedPaths = draft.imagePaths;
    photos = storedPhotos(draft.imagePaths);
  }

  @override
  void dispose() {
    for (final controller in [title, subtitle, summary, story]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _scheduled => publishedAt.isAfter(DateTime.now());

  void _save() {
    setState(() {
      titleError = title.text.trim().isEmpty ? 'Give the story a title.' : null;
    });
    if (titleError != null) return;
    final kept = {for (final photo in photos) ?photo.path};
    commit(
      () async {
        final draft = NewsDraft(
          branchId: lockedBranch ?? branchId,
          title: title.text,
          subtitle: subtitle.text,
          summary: summary.text,
          body: story.text,
          imagePaths: await storePhotos(photos),
          publishedAt: publishedAt,
        );
        await admin.save(kind, editingId, draft.toRow());
      },
      done: editingId != null
          ? 'Saved.'
          : _scheduled
          ? 'Scheduled.'
          : 'Published.',
      removedFiles: [
        for (final path in savedPaths)
          if (!kept.contains(path)) path,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      title: editingId == null ? 'New story' : 'Edit story',
      busy: busy,
      busyLabel: 'Saving…',
      dirty: dirty,
      saveLabel: editingId != null
          ? 'Save changes'
          : _scheduled
          ? 'Schedule'
          : 'Publish',
      onSave: _save,
      onDelete: editingId == null || loadError != null
          ? null
          : () => remove(name: title.text, files: savedPaths),
      deleteLabel: 'Delete story',
      children: body(
        () => [
          FormSection(
            title: 'Story',
            children: [
              LabeledField(
                label: 'Title',
                required: true,
                controller: title,
                error: titleError,
                capitalization: TextCapitalization.words,
                onChanged: (_) => markDirty(),
              ),
              LabeledField(
                label: 'Subtitle',
                controller: subtitle,
                onChanged: (_) => markDirty(),
              ),
              LabeledField(
                label: 'Summary',
                controller: summary,
                lines: 3,
                helper: 'Shown on the card. Two or three sentences.',
                onChanged: (_) => markDirty(),
              ),
              LabeledField(
                label: 'Full story',
                controller: story,
                lines: 8,
                helper: 'Shown when someone opens the story.',
                onChanged: (_) => markDirty(),
              ),
            ],
          ),
          FormSection(
            title: 'Who sees it',
            children: [
              ListenableBuilder(
                listenable: app.sermons,
                builder: (context, _) => BranchChooser(
                  label: 'Branch',
                  branches: branches,
                  value: branchId,
                  lockedTo: lockedBranch,
                  allBranchesLabel: 'All branches',
                  onChanged: (value) => setState(() {
                    branchId = value;
                    dirty = true;
                  }),
                ),
              ),
            ],
          ),
          FormSection(
            title: 'Photos',
            children: [
              PhotoChooser(
                photos: photos,
                onChanged: (value) => setState(() {
                  photos = value;
                  dirty = true;
                }),
              ),
            ],
          ),
          FormSection(
            title: 'When',
            children: [
              DateTimeChooser(
                label: 'Publish',
                value: publishedAt,
                helper:
                    'Set a future time to schedule it. Until then only '
                    'staff can see it.',
                onChanged: (value) => setState(() {
                  publishedAt = value ?? DateTime.now();
                  dirty = true;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Creates or edits an event.
class EventEditor extends StatefulWidget {
  const EventEditor({this.id, super.key});

  final String? id;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor>
    with ContentEditor<EventEditor> {
  @override
  ContentKind get kind => ContentKind.events;
  @override
  String? get editingId => widget.id;

  final title = TextEditingController();
  final host = TextEditingController();
  final description = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final website = TextEditingController();
  String? branchId;
  bool forAllBranches = false;
  DateTime startsAt = EventDraft().startsAt;
  DateTime? endsAt;
  List<PhotoItem> photos = [];
  List<String> savedPaths = [];
  String? titleError;
  String? branchError;
  String? endError;

  @override
  void fill(Map<String, dynamic>? row) {
    if (row == null) {
      branchId = lockedBranch ?? app.sermons.branch?.id;
      return;
    }
    final draft = EventDraft.fromRow(row);
    title.text = draft.title;
    host.text = draft.host;
    description.text = draft.description;
    address.text = draft.address;
    phone.text = draft.phone;
    email.text = draft.email;
    website.text = draft.website;
    branchId = draft.branchId;
    forAllBranches = draft.forAllBranches;
    startsAt = draft.startsAt;
    endsAt = draft.endsAt;
    savedPaths = draft.imagePaths;
    photos = storedPhotos(draft.imagePaths);
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      host,
      description,
      address,
      phone,
      email,
      website,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final branch = lockedBranch ?? branchId;
    setState(() {
      titleError = title.text.trim().isEmpty ? 'Give the event a title.' : null;
      branchError = branch == null ? 'Choose the branch holding it.' : null;
      endError = endsAt != null && !endsAt!.isAfter(startsAt)
          ? 'The end must be after the start.'
          : null;
    });
    if (titleError != null || branchError != null || endError != null) return;
    final kept = {for (final photo in photos) ?photo.path};
    commit(
      () async {
        final draft = EventDraft(
          branchId: branch,
          forAllBranches: role.churchWide && forAllBranches,
          title: title.text,
          startsAt: startsAt,
          endsAt: endsAt,
          host: host.text,
          address: address.text,
          description: description.text,
          phone: phone.text,
          email: email.text,
          website: website.text,
          imagePaths: await storePhotos(photos),
        );
        await admin.save(kind, editingId, draft.toRow());
      },
      done: editingId == null ? 'Event published.' : 'Saved.',
      removedFiles: [
        for (final path in savedPaths)
          if (!kept.contains(path)) path,
      ],
    );
  }

  void _changed(String _) => markDirty();

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      title: editingId == null ? 'New event' : 'Edit event',
      busy: busy,
      busyLabel: 'Saving…',
      dirty: dirty,
      saveLabel: editingId == null ? 'Publish event' : 'Save changes',
      onSave: _save,
      onDelete: editingId == null || loadError != null
          ? null
          : () => remove(name: title.text, files: savedPaths),
      deleteLabel: 'Delete event',
      children: body(
        () => [
          FormSection(
            title: 'Event',
            children: [
              LabeledField(
                label: 'Title',
                required: true,
                controller: title,
                error: titleError,
                capitalization: TextCapitalization.words,
                onChanged: _changed,
              ),
              LabeledField(
                label: 'Host',
                controller: host,
                hint: 'e.g. Rev. Kofi Mensah, Youth Ministry',
                capitalization: TextCapitalization.words,
                onChanged: _changed,
              ),
              LabeledField(
                label: 'Description',
                controller: description,
                lines: 4,
                onChanged: _changed,
              ),
            ],
          ),
          FormSection(
            title: 'When',
            children: [
              DateTimeChooser(
                label: 'Starts',
                value: startsAt,
                onChanged: (value) => setState(() {
                  startsAt = value ?? startsAt;
                  dirty = true;
                }),
              ),
              DateTimeChooser(
                label: 'Ends',
                value: endsAt,
                required: false,
                placeholder: 'Not set (taken as three hours)',
                error: endError,
                onChanged: (value) => setState(() {
                  endsAt = value;
                  dirty = true;
                }),
              ),
            ],
          ),
          FormSection(
            title: 'Where',
            children: [
              ListenableBuilder(
                listenable: app.sermons,
                builder: (context, _) => BranchChooser(
                  label: 'Host branch',
                  branches: branches,
                  value: branchId,
                  lockedTo: lockedBranch,
                  error: branchError,
                  onChanged: (value) => setState(() {
                    branchId = value;
                    dirty = true;
                  }),
                ),
              ),
              if (role.churchWide)
                SwitchRow(
                  title: 'Show to every branch',
                  subtitle:
                      "Members of all branches see it. The host branch's "
                      'live stream is used.',
                  value: forAllBranches,
                  onChanged: (value) => setState(() {
                    forAllBranches = value;
                    dirty = true;
                  }),
                ),
              LabeledField(
                label: 'Address',
                controller: address,
                lines: 2,
                onChanged: _changed,
              ),
            ],
          ),
          FormSection(
            title: 'Contact',
            children: [
              LabeledField(
                label: 'Phone',
                controller: phone,
                keyboardType: TextInputType.phone,
                onChanged: _changed,
              ),
              LabeledField(
                label: 'Email',
                controller: email,
                keyboardType: TextInputType.emailAddress,
                capitalization: TextCapitalization.none,
                onChanged: _changed,
              ),
              LabeledField(
                label: 'Website',
                controller: website,
                keyboardType: TextInputType.url,
                capitalization: TextCapitalization.none,
                onChanged: _changed,
              ),
            ],
          ),
          FormSection(
            title: 'Photos',
            children: [
              PhotoChooser(
                photos: photos,
                onChanged: (value) => setState(() {
                  photos = value;
                  dirty = true;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uploads or edits a sermon recording.
class SermonEditor extends StatefulWidget {
  const SermonEditor({this.id, super.key});

  final String? id;

  @override
  State<SermonEditor> createState() => _SermonEditorState();
}

class _SermonEditorState extends State<SermonEditor>
    with ContentEditor<SermonEditor> {
  @override
  ContentKind get kind => ContentKind.sermons;
  @override
  String? get editingId => widget.id;

  /// Supabase's upload limit on its free plan.
  static const maxBytes = 50 * 1024 * 1024;

  final title = TextEditingController();
  final preacher = TextEditingController();
  final notes = TextEditingController();
  final minutes = TextEditingController();
  String? branchId;
  DateTime preachedOn = DateTime.now();
  String savedAudio = '';
  PlatformFile? newAudio;
  String? titleError;
  String? audioError;

  @override
  void fill(Map<String, dynamic>? row) {
    if (row == null) {
      branchId = lockedBranch ?? app.sermons.branch?.id;
      return;
    }
    final draft = SermonDraft.fromRow(row);
    title.text = draft.title;
    preacher.text = draft.preacher;
    notes.text = draft.description;
    minutes.text = draft.durationMinutes?.toString() ?? '';
    branchId = draft.branchId;
    preachedOn = draft.preachedOn;
    savedAudio = draft.audioPath;
  }

  @override
  void dispose() {
    for (final controller in [title, preacher, notes, minutes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseAudio() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
    );
    if (file == null) return;
    final size = await file.length() ?? 0;
    setState(() {
      if (size > maxBytes) {
        audioError =
            'This recording is over 50 MB. Export it as MP3 at 64 kbps mono '
            '(about 30 MB an hour) and choose it again.';
        return;
      }
      newAudio = file;
      audioError = null;
      dirty = true;
    });
  }

  static String _audioType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/mpeg';
  }

  void _save() {
    final branch = lockedBranch ?? branchId;
    setState(() {
      titleError = title.text.trim().isEmpty
          ? 'Give the sermon a title.'
          : null;
      audioError = newAudio == null && savedAudio.isEmpty
          ? 'Choose the recording.'
          : audioError;
    });
    if (titleError != null || audioError != null) return;
    final replacing = newAudio != null && savedAudio.isNotEmpty;
    commit(
      () async {
        var audioPath = savedAudio;
        final file = newAudio;
        if (file != null) {
          audioPath = await admin.upload(
            kind.bucket,
            file.name,
            await file.xFile.readAsBytes(),
            _audioType(file.name),
          );
        }
        final draft = SermonDraft(
          branchId: branch,
          title: title.text,
          preacher: preacher.text,
          preachedOn: preachedOn,
          description: notes.text,
          audioPath: audioPath,
          durationMinutes: int.tryParse(minutes.text.trim()),
        );
        await admin.save(kind, editingId, draft.toRow());
      },
      done: editingId == null ? 'Sermon published.' : 'Saved.',
      removedFiles: replacing ? [savedAudio] : const [],
    );
  }

  String get _audioLabel {
    final file = newAudio;
    if (file != null) return file.name;
    if (savedAudio.isNotEmpty) return savedAudio.split('/').last;
    return 'Choose the recording';
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      title: editingId == null ? 'New sermon' : 'Edit sermon',
      busy: busy,
      busyLabel: newAudio != null
          ? 'Uploading the recording. Keep the app open.'
          : 'Saving…',
      dirty: dirty,
      saveLabel: editingId == null ? 'Publish sermon' : 'Save changes',
      onSave: _save,
      onDelete: editingId == null || loadError != null
          ? null
          : () => remove(
              name: title.text,
              files: [if (savedAudio.isNotEmpty) savedAudio],
            ),
      deleteLabel: 'Delete sermon',
      children: body(
        () => [
          FormSection(
            title: 'Recording',
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Audio file', required: true),
                  const SizedBox(height: 6),
                  PickerBox(
                    icon: Icons.audio_file_outlined,
                    text: _audioLabel,
                    placeholder: newAudio == null && savedAudio.isEmpty,
                    error: audioError,
                    onTap: _chooseAudio,
                    trailing: const Icon(Icons.upload, color: CccColors.ink),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 6),
                    child: Text(
                      'MP3, M4A, AAC, WAV or OGG, up to 50 MB.',
                      style: TextStyle(fontSize: 13, color: CccColors.muted),
                    ),
                  ),
                ],
              ),
              LabeledField(
                label: 'Length in minutes',
                controller: minutes,
                keyboardType: TextInputType.number,
                helper: 'Optional. Shown before the recording loads.',
                onChanged: (_) => markDirty(),
              ),
            ],
          ),
          FormSection(
            title: 'Sermon',
            children: [
              LabeledField(
                label: 'Title',
                required: true,
                controller: title,
                error: titleError,
                capitalization: TextCapitalization.words,
                onChanged: (_) => markDirty(),
              ),
              LabeledField(
                label: 'Preacher',
                controller: preacher,
                capitalization: TextCapitalization.words,
                onChanged: (_) => markDirty(),
              ),
              DateTimeChooser(
                label: 'Preached on',
                value: preachedOn,
                withTime: false,
                onChanged: (value) => setState(() {
                  preachedOn = value ?? preachedOn;
                  dirty = true;
                }),
              ),
              LabeledField(
                label: 'Sermon notes',
                controller: notes,
                lines: 4,
                helper: 'Shown in the player.',
                onChanged: (_) => markDirty(),
              ),
              ListenableBuilder(
                listenable: app.sermons,
                builder: (context, _) => BranchChooser(
                  label: 'Branch',
                  branches: branches,
                  value: branchId,
                  lockedTo: lockedBranch,
                  allBranchesLabel: 'All branches',
                  onChanged: (value) => setState(() {
                    branchId = value;
                    dirty = true;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Adds or edits a ministry.
class MinistryEditor extends StatefulWidget {
  const MinistryEditor({this.id, super.key});

  final String? id;

  @override
  State<MinistryEditor> createState() => _MinistryEditorState();
}

class _MinistryEditorState extends State<MinistryEditor>
    with ContentEditor<MinistryEditor> {
  @override
  ContentKind get kind => ContentKind.ministries;
  @override
  String? get editingId => widget.id;

  final name = TextEditingController();
  final focus = TextEditingController();
  final about = TextEditingController();
  final meets = TextEditingController();
  final venue = TextEditingController();
  final members = TextEditingController();
  final order = TextEditingController(text: '0');
  String? branchId;
  List<PhotoItem> photos = [];
  List<String> savedPaths = [];
  String? nameError;

  @override
  void fill(Map<String, dynamic>? row) {
    if (row == null) {
      branchId = lockedBranch;
      return;
    }
    final draft = MinistryDraft.fromRow(row);
    name.text = draft.name;
    focus.text = draft.focus;
    about.text = draft.about;
    meets.text = draft.meets;
    venue.text = draft.venue;
    members.text = draft.membersLabel;
    order.text = '${draft.sortOrder}';
    branchId = draft.branchId;
    savedPaths = draft.imagePaths;
    photos = storedPhotos(draft.imagePaths);
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      focus,
      about,
      meets,
      venue,
      members,
      order,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    setState(() {
      nameError = name.text.trim().isEmpty ? 'Give the ministry a name.' : null;
    });
    if (nameError != null) return;
    final kept = {for (final photo in photos) ?photo.path};
    commit(
      () async {
        final draft = MinistryDraft(
          branchId: lockedBranch ?? branchId,
          name: name.text,
          focus: focus.text,
          about: about.text,
          meets: meets.text,
          venue: venue.text,
          membersLabel: members.text,
          sortOrder: int.tryParse(order.text.trim()) ?? 0,
          imagePaths: await storePhotos(photos),
        );
        await admin.save(kind, editingId, draft.toRow());
      },
      done: editingId == null ? 'Ministry added.' : 'Saved.',
      removedFiles: [
        for (final path in savedPaths)
          if (!kept.contains(path)) path,
      ],
    );
  }

  void _changed(String _) => markDirty();

  @override
  Widget build(BuildContext context) {
    final id = editingId;
    return AdminFormScaffold(
      title: id == null ? 'New ministry' : 'Edit ministry',
      busy: busy,
      busyLabel: 'Saving…',
      dirty: dirty,
      saveLabel: id == null ? 'Add ministry' : 'Save changes',
      onSave: _save,
      onDelete: id == null || loadError != null
          ? null
          : () => remove(name: name.text, files: savedPaths),
      deleteLabel: 'Delete ministry',
      children: body(
        () => [
          if (id != null) ...[
            CccButton(
              label: 'See who has joined',
              variant: CccButtonVariant.outlined,
              height: 48,
              fontSize: 16,
              iconGap: 10,
              icon: const Icon(Icons.people_outline, size: 22),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SignupsScreen(ministryId: id, ministryName: name.text),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FormSection(
            title: 'Ministry',
            children: [
              LabeledField(
                label: 'Name',
                required: true,
                controller: name,
                error: nameError,
                capitalization: TextCapitalization.words,
                onChanged: _changed,
              ),
              LabeledField(
                label: "Who it's for",
                controller: focus,
                hint: "e.g. Women's fellowship, Ages 18 to 35",
                onChanged: _changed,
              ),
              LabeledField(
                label: 'About',
                controller: about,
                lines: 4,
                onChanged: _changed,
              ),
            ],
          ),
          FormSection(
            title: 'Meetings',
            children: [
              LabeledField(
                label: 'When it meets',
                controller: meets,
                hint: 'e.g. Saturdays, 4:00 PM',
                onChanged: _changed,
              ),
              LabeledField(
                label: 'Venue',
                controller: venue,
                capitalization: TextCapitalization.words,
                onChanged: _changed,
              ),
              ListenableBuilder(
                listenable: app.sermons,
                builder: (context, _) => BranchChooser(
                  label: 'Branch',
                  branches: branches,
                  value: branchId,
                  lockedTo: lockedBranch,
                  allBranchesLabel: 'Church-wide',
                  onChanged: (value) => setState(() {
                    branchId = value;
                    dirty = true;
                  }),
                ),
              ),
            ],
          ),
          FormSection(
            title: 'Photos',
            children: [
              PhotoChooser(
                photos: photos,
                onChanged: (value) => setState(() {
                  photos = value;
                  dirty = true;
                }),
              ),
            ],
          ),
          FormSection(
            title: 'On the card',
            children: [
              LabeledField(
                label: 'Members',
                controller: members,
                hint: 'e.g. 50+',
                helper:
                    'Shown as “50+ members”. Leave empty to hide. Use only a '
                    'figure the ministry has confirmed.',
                onChanged: _changed,
              ),
              LabeledField(
                label: 'Order',
                controller: order,
                keyboardType: TextInputType.number,
                helper: 'Lower numbers show first; ties go by name.',
                onChanged: _changed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
