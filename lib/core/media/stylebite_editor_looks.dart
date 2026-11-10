import 'package:pro_image_editor/pro_image_editor.dart';

/// StyleBite hero looks — DAEDAL CC0 `.cube` LUTs + matrix preview companions.
class StyleBiteEditorLooks {
  StyleBiteEditorLooks._();

  /// Asset path for real 3D LUT bake, or null for Original / matrix-only.
  static String? cubeAssetFor(String name) => _cubeByName[name];

  static const Map<String, String> _cubeByName = {
    'Teal Orange': 'assets/luts/teal_orange.cube',
    'Blockbuster': 'assets/luts/blockbuster.cube',
    'Moody': 'assets/luts/moody.cube',
    'Night City': 'assets/luts/night_city.cube',
    'Bleach': 'assets/luts/bleach.cube',
    'Desert': 'assets/luts/desert.cube',
    'Nordic': 'assets/luts/nordic.cube',
    'Forest': 'assets/luts/forest.cube',
    'Golden Hour': 'assets/luts/golden_hour.cube',
    'Soft Plate': 'assets/luts/soft_plate.cube',
    'Cream': 'assets/luts/cream.cube',
    'Food Pop': 'assets/luts/food_pop.cube',
    'Bite Punch': 'assets/luts/bite_punch.cube',
    'Studio Outfit': 'assets/luts/studio_outfit.cube',
    'Night Out': 'assets/luts/night_out.cube',
    'Plate Glow': 'assets/luts/plate_glow.cube',
    'Runway Cool': 'assets/luts/runway_cool.cube',
    'Film Still': 'assets/luts/film_still.cube',
    'Mono': 'assets/luts/mono.cube',
    'Clean Matte': 'assets/luts/clean_matte.cube',
    'Willow Soft': 'assets/luts/willow_soft.cube',
  };

  /// Curated strip — cinematic-first, then StyleBite food/fashion.
  static final List<FilterModel> all = <FilterModel>[
    const FilterModel(name: 'Original', filters: []),
    _look(
      'Teal Orange',
      [
        ColorFilterAddons.temperature(-0.08),
        ColorFilterAddons.saturation(0.12),
        ColorFilterAddons.contrast(0.16),
        ColorFilterAddons.colorOverlay(255, 140, 60, 0.07),
        ColorFilterAddons.rgbScale(0.97, 1.0, 1.06),
      ],
    ),
    _look(
      'Blockbuster',
      [
        ColorFilterAddons.contrast(0.2),
        ColorFilterAddons.saturation(0.1),
        ColorFilterAddons.exposure(0.04),
        ColorFilterAddons.temperature(0.06),
        ColorFilterAddons.colorOverlay(255, 120, 40, 0.05),
      ],
    ),
    _look(
      'Moody',
      [
        ColorFilterAddons.contrast(0.14),
        ColorFilterAddons.saturation(-0.08),
        ColorFilterAddons.exposure(-0.08),
        ColorFilterAddons.temperature(-0.06),
        ColorFilterAddons.fade(0.1),
      ],
    ),
    _look(
      'Night City',
      [
        ColorFilterAddons.contrast(0.16),
        ColorFilterAddons.saturation(0.1),
        ColorFilterAddons.temperature(-0.12),
        ColorFilterAddons.exposure(-0.05),
        ColorFilterAddons.colorOverlay(30, 50, 120, 0.08),
      ],
    ),
    _look(
      'Bleach',
      [
        ColorFilterAddons.saturation(-0.22),
        ColorFilterAddons.contrast(0.22),
        ColorFilterAddons.brightness(0.06),
        ColorFilterAddons.fade(0.08),
      ],
    ),
    _look(
      'Desert',
      [
        ColorFilterAddons.temperature(0.18),
        ColorFilterAddons.saturation(0.08),
        ColorFilterAddons.contrast(0.1),
        ColorFilterAddons.colorOverlay(255, 170, 80, 0.08),
      ],
    ),
    _look(
      'Nordic',
      [
        ColorFilterAddons.temperature(-0.14),
        ColorFilterAddons.saturation(-0.1),
        ColorFilterAddons.contrast(0.08),
        ColorFilterAddons.brightness(0.05),
        ColorFilterAddons.rgbScale(0.98, 1.0, 1.04),
      ],
    ),
    _look(
      'Forest',
      [
        ColorFilterAddons.saturation(0.06),
        ColorFilterAddons.contrast(0.1),
        ColorFilterAddons.temperature(-0.04),
        ColorFilterAddons.colorOverlay(40, 90, 50, 0.06),
      ],
    ),
    _look(
      'Golden Hour',
      [
        ColorFilterAddons.temperature(0.2),
        ColorFilterAddons.saturation(0.1),
        ColorFilterAddons.exposure(0.09),
        ColorFilterAddons.contrast(0.06),
        ColorFilterAddons.colorOverlay(255, 170, 80, 0.08),
      ],
    ),
    _look(
      'Food Pop',
      [
        ColorFilterAddons.contrast(0.14),
        ColorFilterAddons.saturation(0.2),
        ColorFilterAddons.temperature(0.07),
        ColorFilterAddons.brightness(0.04),
        ColorFilterAddons.colorOverlay(255, 140, 60, 0.06),
      ],
    ),
    _look(
      'Bite Punch',
      [
        ColorFilterAddons.contrast(0.2),
        ColorFilterAddons.saturation(0.24),
        ColorFilterAddons.exposure(0.06),
        ColorFilterAddons.temperature(0.05),
        ColorFilterAddons.colorOverlay(255, 90, 60, 0.05),
      ],
    ),
    _look(
      'Soft Plate',
      [
        ColorFilterAddons.fade(0.24),
        ColorFilterAddons.contrast(-0.07),
        ColorFilterAddons.saturation(-0.06),
        ColorFilterAddons.brightness(0.07),
        ColorFilterAddons.rgbScale(1.02, 1.0, 0.98),
      ],
    ),
    _look(
      'Cream',
      [
        ColorFilterAddons.sepia(0.1),
        ColorFilterAddons.fade(0.2),
        ColorFilterAddons.temperature(0.12),
        ColorFilterAddons.contrast(-0.05),
        ColorFilterAddons.addictiveColor(12, 8, 0),
      ],
    ),
    _look(
      'Mono',
      [
        ColorFilterAddons.grayscale(),
        ColorFilterAddons.contrast(0.14),
        ColorFilterAddons.brightness(0.04),
        ColorFilterAddons.fade(0.05),
      ],
    ),
  ];

  /// Favorites first, then the rest.
  static List<FilterModel> ordered(Set<String> favoriteNames) {
    if (favoriteNames.isEmpty) return all;
    final favs = <FilterModel>[];
    final rest = <FilterModel>[];
    for (final look in all) {
      if (look.name != 'Original' && favoriteNames.contains(look.name)) {
        favs.add(look);
      } else {
        rest.add(look);
      }
    }
    return [...favs, ...rest];
  }

  static FilterModel byName(String name) {
    for (final look in all) {
      if (look.name == name) return look;
    }
    return all.first;
  }

  static FilterModel _look(String name, List<List<double>> filters) {
    return FilterModel(name: name, filters: filters);
  }
}
