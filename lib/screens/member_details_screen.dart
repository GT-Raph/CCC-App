import 'package:flutter/material.dart';

import '../models/member_details.dart';
import '../services/church_query.dart';
import '../state/ccc_state.dart';
import '../theme/ccc_theme.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/option_chips.dart';

/// Opens [MemberDetailsScreen], then tells the member which ministries they
/// were added to.
Future<void> openMemberDetails(
  BuildContext context, {
  bool firstTime = false,
}) async {
  final directory = CccScope.of(context).ministries;
  final added = await Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      builder: (_) => MemberDetailsScreen(
        initial: directory.details,
        firstTime: firstTime,
      ),
    ),
  );
  if (added == null || !context.mounted) return;
  showCccMessage(
    context,
    added.isEmpty
        ? 'Your details are saved.'
        : addedToMinistriesMessage(added),
  );
}

/// Asks a member for the details that match them with ministries: once
/// after they sign in ([firstTime], with Skip for now), and from their
/// account whenever they like. Pops with the names of the ministries they
/// were just added to, or null if they skipped or went back.
class MemberDetailsScreen extends StatefulWidget {
  const MemberDetailsScreen({this.initial, this.firstTime = false, super.key});

  final MemberDetails? initial;
  final bool firstTime;

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  late DateTime? birthDate = widget.initial?.birthDate;
  late Gender? gender = widget.initial?.gender;
  late MaritalStatus? maritalStatus = widget.initial?.maritalStatus;
  late bool? student = widget.initial?.student;
  bool busy = false;

  static const _months = [
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

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(today.year - 25, today.month),
      firstDate: DateTime(1900),
      lastDate: today,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => birthDate = picked);
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final added = await CccScope.of(context).ministries.saveDetails(
        MemberDetails(
          birthDate: birthDate,
          gender: gender,
          maritalStatus: maritalStatus,
          student: student,
        ),
      );
      if (mounted) Navigator.pop(context, added);
    } on ChurchDataException catch (error) {
      if (!mounted) return;
      setState(() => busy = false);
      showCccMessage(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      showCccMessage(context, "Couldn't save your details. Try again.");
    }
  }

  /// Remembers that the member was asked, so the app doesn't ask again.
  Future<void> _skip() async {
    setState(() => busy = true);
    try {
      await CccScope.of(context).ministries.saveDetails(MemberDetails.skipped);
    } catch (_) {
      // Then the app asks again next time, which is fine.
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final birth = birthDate;
    Widget question(String label, Widget answer) => Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [FieldLabel(label), const SizedBox(height: 10), answer],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          const DetailsHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
              children: [
                const AuthTitle(
                  title: 'About you',
                  subtitle:
                      "Tell us a little about yourself and we'll add you to "
                      'the ministries that are for you, like your age group '
                      'or fellowship. Every answer is optional.',
                ),
                question(
                  'Date of birth',
                  InkWell(
                    onTap: busy ? null : _pickBirthDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      isEmpty: birth == null,
                      decoration: cccFieldDecoration(
                        context,
                        hint: 'Choose a date',
                        suffixIcon: birth == null
                            ? Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: p.textMuted,
                              )
                            : IconButton(
                                tooltip: 'Clear date of birth',
                                onPressed: () =>
                                    setState(() => birthDate = null),
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: p.textMuted,
                                ),
                              ),
                      ),
                      child: Text(
                        birth == null
                            ? ''
                            : '${birth.day} ${_months[birth.month - 1]} '
                                  '${birth.year}',
                        style: TextStyle(fontSize: 16, color: p.text),
                      ),
                    ),
                  ),
                ),
                question(
                  'Gender',
                  OptionChips<Gender>(
                    options: [for (final g in Gender.values) (g, g.label)],
                    selected: {?gender},
                    onChanged: (value) =>
                        setState(() => gender = value.firstOrNull),
                  ),
                ),
                question(
                  'Marital status',
                  OptionChips<MaritalStatus>(
                    options: [
                      for (final status in MaritalStatus.values)
                        (status, status.label),
                    ],
                    selected: {?maritalStatus},
                    onChanged: (value) =>
                        setState(() => maritalStatus = value.firstOrNull),
                  ),
                ),
                question(
                  'Are you a student?',
                  OptionChips<bool>(
                    options: const [(true, 'Yes'), (false, 'No')],
                    selected: {?student},
                    onChanged: (value) =>
                        setState(() => student = value.firstOrNull),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only you can see these details. Ministry leaders '
                        "see only which ministries you're in. You can change "
                        'your answers or leave a ministry at any time.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                CccButton(label: 'Save', isLoading: busy, onPressed: _save),
                if (widget.firstTime) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: p.textSecondary,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: const TextStyle(
                        fontFamily: CccFonts.openSans,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Skip for now'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
