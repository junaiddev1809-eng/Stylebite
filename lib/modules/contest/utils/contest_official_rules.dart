/// App Store Guideline 5.3.2 — official contest copy that must stay in-app.
class ContestOfficialRules {
  ContestOfficialRules._();

  static const String sponsor =
      'This contest is sponsored and operated solely by StyleBite.';

  static const String appleDisclaimer =
      'Apple is not a sponsor of this contest or sweepstakes and is not '
      'involved in it in any manner.';

  /// Fallback official rules when a contest has no custom rules from the API.
  static const List<String> fallbackRules = [
    sponsor,
    appleDisclaimer,
    'Post an original entry that matches the contest theme.',
    'Community ratings use a 1–5 score. Final score = (average rating × 70) + (likes × 0.3).',
    'A submission needs the minimum active ratings shown for this contest before it can win a prize place.',
    'Banned or deleted accounts and blocked posts do not count toward the ranking.',
    'Winners are assigned when the contest ends, based on eligible final scores.',
    'By joining, you agree to these Official Contest Rules.',
  ];

  static bool isAppleDisclaimer(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('apple is not a sponsor') ||
        normalized.contains('apple is not involved');
  }

  static bool isSponsorLine(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('sponsored and operated solely by stylebite') ||
        normalized.contains('organized by stylebite');
  }

  /// Merge API rules with required App Store statements (never drop them).
  static List<String> mergeWithRequired(List<String> apiRules) {
    final merged = <String>[];
    final seen = <String>{};

    void add(String text) {
      final clean = text.trim();
      if (clean.isEmpty) return;
      final key = clean.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      merged.add(clean);
    }

    add(sponsor);
    add(appleDisclaimer);

    for (final rule in apiRules) {
      if (isAppleDisclaimer(rule) || isSponsorLine(rule)) {
        continue;
      }
      add(rule);
    }

    if (merged.length <= 2) {
      for (final rule in fallbackRules) {
        add(rule);
      }
    }

    return List<String>.unmodifiable(merged);
  }
}
