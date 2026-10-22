/// Shared threshold for profile section load-more.
///
/// Matches the existing scroll listener: when the user is within this many
/// pixels of the bottom, the next page may load.
const double profilePaginationEdgePixels = 220;

/// Whether the profile list is near enough to the bottom to request another page.
///
/// Short, non-scrolling lists report [maxScrollExtent] of 0, so they still
/// return true and keep intended auto-fill pagination. Lists parked at the
/// top of a long scroll return false.
bool isNearProfilePaginationEdge({
  required double pixels,
  required double maxScrollExtent,
  double threshold = profilePaginationEdgePixels,
}) {
  return pixels >= maxScrollExtent - threshold;
}
