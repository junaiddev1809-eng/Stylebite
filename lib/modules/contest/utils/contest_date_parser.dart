final RegExp _hasTimezoneMarker = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// Contest times are Pakistan time (Asia/Karachi, GMT+5, no daylight saving).
/// A timestamp with no offset is that wall-clock time. The returned value
/// stays a real instant so countdowns still match the phone clock.
DateTime? parseContestDate(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty || raw == 'null') {
    return null;
  }

  final isoLike = raw.replaceFirst(' ', 'T');
  final withZone = _hasTimezoneMarker.hasMatch(isoLike)
      ? isoLike
      : '$isoLike+05:00';

  return DateTime.tryParse(withZone)?.toLocal();
}

/// Clock numbers in Pakistan, for labels. Countdowns should keep using
/// [parseContestDate] directly.
DateTime? contestPakistanClock(DateTime? value) {
  if (value == null) {
    return null;
  }
  final shifted = value.toUtc().add(const Duration(hours: 5));
  return DateTime.utc(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
  );
}
