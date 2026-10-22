import '../models/profile_model.dart';

/// Query string for one profile overview request.
///
/// Omitting every page leaves the released contract: the server returns
/// outfits, food, and saved together. Naming one page asks for that section.
Map<String, String> profileOverviewQuery({
  int? outfitPage,
  int? foodPage,
  int? savedPage,
  int perPage = 10,
}) {
  final params = <String, String>{'per_page': '$perPage'};
  if (outfitPage != null) {
    params['outfit_page'] = '$outfitPage';
  }
  if (foodPage != null) {
    params['food_page'] = '$foodPage';
  }
  if (savedPage != null) {
    params['saved_page'] = '$savedPage';
  }
  return params;
}

/// Page numbers for the section a profile tab should fetch.
({int? outfitPage, int? foodPage, int? savedPage}) profileSectionPages(
  ProfileContentTab tab,
  int page,
) {
  return (
    outfitPage: tab == ProfileContentTab.outfits ? page : null,
    foodPage: tab == ProfileContentTab.food ? page : null,
    savedPage: tab == ProfileContentTab.saved ? page : null,
  );
}
