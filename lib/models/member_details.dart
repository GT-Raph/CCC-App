/// A member's gender, for men's and women's ministries.
enum Gender {
  male('Male', 'Men'),
  female('Female', 'Women');

  const Gender(this.label, this.groupLabel);

  /// How a member describes themselves.
  final String label;

  /// Who a ministry is for, on the staff form.
  final String groupLabel;

  static Gender? fromName(Object? value) => Gender.values.asNameMap()[value];
}

enum MaritalStatus {
  single('Single'),
  married('Married'),
  widowed('Widowed'),
  divorced('Divorced'),
  separated('Separated');

  const MaritalStatus(this.label);

  final String label;

  static MaritalStatus? fromName(Object? value) =>
      MaritalStatus.values.asNameMap()[value];
}

/// What a member tells the app about themselves so it can add them to the
/// ministries that are for them (supabase/ministry_matching.sql). Every
/// detail is optional; only the member can see them.
class MemberDetails {
  const MemberDetails({
    this.birthDate,
    this.gender,
    this.maritalStatus,
    this.student,
  });

  /// A `member_details` row.
  factory MemberDetails.fromRow(Map<String, dynamic> row) {
    final birth = row['birth_date'] as String?;
    return MemberDetails(
      birthDate: birth == null ? null : DateTime.parse(birth),
      gender: Gender.fromName(row['gender']),
      maritalStatus: MaritalStatus.fromName(row['marital_status']),
      student: row['student'] as bool?,
    );
  }

  /// A member who chose to skip: asked, and nothing given.
  static const skipped = MemberDetails();

  /// A calendar day; only its year, month and day are used.
  final DateTime? birthDate;
  final Gender? gender;
  final MaritalStatus? maritalStatus;
  final bool? student;

  bool get isEmpty =>
      birthDate == null &&
      gender == null &&
      maritalStatus == null &&
      student == null;

  /// The date without a time zone, so it is the same day everywhere.
  Map<String, Object?> toRow() => {
    'birth_date': switch (birthDate) {
      final date? =>
        '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      null => null,
    },
    'gender': gender?.name,
    'marital_status': maritalStatus?.name,
    'student': student,
  };
}

/// "You've been added to Youth.", "… to Youth and Women's Fellowship.", or
/// "… to Choir, Youth and Ushers."
String addedToMinistriesMessage(List<String> names) {
  final list = switch (names.length) {
    0 => '',
    1 => names.single,
    _ =>
      '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
  };
  return "You've been added to $list.";
}
