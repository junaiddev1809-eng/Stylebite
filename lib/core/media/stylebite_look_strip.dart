import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'stylebite_editor_looks.dart';
import 'stylebite_filter_baker.dart';
import 'stylebite_look_favorites.dart';

/// Horizontal StyleBite look picker — favorites first; long-press to favorite.
class StyleBiteLookStrip extends StatefulWidget {
  const StyleBiteLookStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final FilterModel selected;
  final ValueChanged<FilterModel> onSelected;
  final bool compact;

  @override
  State<StyleBiteLookStrip> createState() => _StyleBiteLookStripState();
}

class _StyleBiteLookStripState extends State<StyleBiteLookStrip> {
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await StyleBiteLookFavorites.load();
    if (!mounted) return;
    setState(() => _favorites = favs);
  }

  Future<void> _toggleFavorite(FilterModel look) async {
    final next = await StyleBiteLookFavorites.toggle(look.name);
    if (!mounted) return;
    setState(() => _favorites = next);
  }

  @override
  Widget build(BuildContext context) {
    final looks = StyleBiteEditorLooks.ordered(_favorites);
    final size = widget.compact ? 52.0 : 60.0;

    return SizedBox(
      height: widget.compact ? 78 : 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: looks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final look = looks[index];
          final selected = look.name == widget.selected.name;
          final fav = _favorites.contains(look.name);
          return GestureDetector(
            onTap: () => widget.onSelected(look),
            onLongPress: look.name == 'Original'
                ? null
                : () => _toggleFavorite(look),
            child: SizedBox(
              width: size + 10,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: size,
                        height: size,
                        padding: EdgeInsets.all(selected ? 2.4 : 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.white24,
                            width: selected ? 2.4 : 1,
                          ),
                        ),
                        child: ClipOval(
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(
                              StyleBiteFilterBaker.matrixFor(look, 1),
                            ),
                            child: Container(
                              color: const Color(0xFFE8DCD6),
                              alignment: Alignment.center,
                              child: Text(
                                look.name == 'Original' ? '∅' : look.name[0],
                                style: AppFonts.plusJakarta(
                                  size: widget.compact ? 16 : 18,
                                  weight: FontWeight.w800,
                                  color: const Color(0xFF3A2F33),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (fav)
                        const Positioned(
                          right: -2,
                          top: -2,
                          child: Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    look.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppFonts.plusJakarta(
                      size: 10,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
