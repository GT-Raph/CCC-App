/// Google Maps searches that together find the Calvary Charismatic Centre
/// branches. Branch listings are named inconsistently ("Calvary Charismatic
/// Center(CCC) Adom…", "CCC Westland (Calvary Charismatic Center)",
/// "CCC Botwe"), so one query alone misses some of them.
const branchSearchQueries = [
  'CCC Calvary Charismatic',
  'Calvary Charismatic Centre',
  'Calvary Charismatic Center',
];

final _churchName = RegExp(r'calvary\s+charismatic', caseSensitive: false);
final _cccPrefix = RegExp(r'^ccc\b', caseSensitive: false);
final _otherChurches = RegExp(r'celestial|parish', caseSensitive: false);

/// Keeps Calvary Charismatic Centre branches and drops the similarly named
/// churches Google also returns (Calvary Worship Centre, ICGC Calvary Temple,
/// Celestial Church of Christ parishes, …).
bool isChurchBranch(String name) =>
    !_otherChurches.hasMatch(name) &&
    (_churchName.hasMatch(name) || _cccPrefix.hasMatch(name));
