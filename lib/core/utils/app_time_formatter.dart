class AppTimeFormatter {
  AppTimeFormatter._();

  static const List<String> _months = <String>[
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

  static final RegExp _hasTimezoneMarker = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  static DateTime? parse(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final isoLike = normalized.replaceFirst(' ', 'T');
    // Prefer API timestamps with an offset (ISO-8601). Honor that offset,
    // then convert to the device's local timezone so times match where the
    // user lives. Bare "yyyy-MM-dd HH:mm:ss" (legacy) is treated as UTC.
    final withZone = _hasTimezoneMarker.hasMatch(isoLike)
        ? isoLike
        : '${isoLike}Z';

    return DateTime.tryParse(withZone)?.toLocal();
  }

  static String formatPostTime(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Just now';
    }
    // Already a UI label (local post / previous format) — don't re-parse.
    if (!_looksLikeTimestamp(trimmed)) {
      return trimmed;
    }

    final parsed = parse(trimmed);
    if (parsed == null) {
      return 'Just now';
    }
    return formatPostTimeValue(parsed);
  }

  /// [value] must already be in the device's local timezone.
  static String formatPostTimeValue(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    final clock = _formatClock(value);

    // Future / clock skew → still show device-local clock, never raw ISO.
    if (diff.isNegative || diff.inMinutes < 1) {
      return clock;
    }

    if (diff.inHours < 12) {
      return clock;
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }

    if (diff.inDays < 30) {
      return '${diff.inDays}d';
    }

    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      final safeMonths = months <= 0 ? 1 : months;
      return '${safeMonths}month';
    }

    final years = (diff.inDays / 365).floor();
    final safeYears = years <= 0 ? 1 : years;
    return '$safeYears year ago';
  }

  static bool _looksLikeTimestamp(String value) {
    if (value.contains('T') || RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      return true;
    }
    return DateTime.tryParse(value.replaceFirst(' ', 'T')) != null;
  }

  static String formatCommentTime(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) {
      return 'Just now';
    }

    final now = DateTime.now();
    final diff = now.difference(parsed);

    if (diff.inSeconds < 60) {
      final seconds = diff.inSeconds <= 0 ? 1 : diff.inSeconds;
      return '${seconds}s';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }

    if (diff.inDays < 30) {
      return '${diff.inDays}d';
    }

    return '${parsed.day} ${_months[parsed.month - 1]}-${parsed.year}';
  }

  static String formatCompactDate(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) {
      return '';
    }
    return formatCompactDateValue(parsed);
  }

  // See formatFullDateTimeValue — same reasoning: format an
  // already-local DateTime directly, don't round-trip it through parse().
  static String formatCompactDateValue(DateTime value) {
    final now = DateTime.now();
    final sameYear = value.year == now.year;
    final monthName = _months[value.month - 1];
    return sameYear
        ? '${value.day} $monthName'
        : '${value.day} $monthName ${value.year}';
  }

  static String formatBannerDate(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(parsed.year, parsed.month, parsed.day);

    if (messageDate == today) return 'Today';
    if (messageDate == yesterday) return 'Yesterday';

    return formatCompactDate(raw);
  }

  static String formatFullDateTime(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) {
      return '';
    }
    return formatFullDateTimeValue(parsed);
  }

  // For a DateTime you already hold (e.g. already parsed/converted to
  // local by a model) — do NOT round-trip it through toIso8601String()
  // and formatFullDateTime(). A local DateTime's ISO string carries no
  // timezone marker, so parse() above would assume it's UTC and convert
  // it to local a second time, double-shifting the displayed time.
  static String formatFullDateTimeValue(DateTime value) {
    final monthName = _months[value.month - 1];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day} $monthName ${value.year}, $hour:$minute $suffix';
  }

  static String _formatClock(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static bool isSameDay(String? date1, String? date2) {
    final p1 = parse(date1);
    final p2 = parse(date2);
    if (p1 == null || p2 == null) return false;
    return p1.year == p2.year && p1.month == p2.month && p1.day == p2.day;
  }
}
