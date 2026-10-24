import '../../../core/utils/app_time_formatter.dart';

/// Contest schedule timestamps from the API (ISO-8601 with offset).
/// Returns the device-local instant so countdowns and labels match where
/// the user lives.
DateTime? parseContestDate(dynamic value) {
  return AppTimeFormatter.parse(value?.toString());
}
