import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'stylebite_editor_chrome.dart';

/// Offline decorative stickers for Stories (no network / no music).
class StyleBiteStoryStickers {
  StyleBiteStoryStickers._();

  static const List<StyleBiteStickerSpec> _pack = <StyleBiteStickerSpec>[
    StyleBiteStickerSpec('🔥 LIT', Color(0xFFFF6B4A)),
    StyleBiteStickerSpec('✨ GLOW', Color(0xFFFF9FF3)),
    StyleBiteStickerSpec('😍 YUM', Color(0xFFFF6B4A)),
    StyleBiteStickerSpec('👗 OOTD', Color(0xFFFF4D6D)),
    StyleBiteStickerSpec('🥗 FRESH', Color(0xFF2ECC71)),
    StyleBiteStickerSpec('📸 FIT CHECK', Color(0xFF6C5CE7)),
    StyleBiteStickerSpec('🆕 NEW IN', Color(0xFF00CEC9)),
    StyleBiteStickerSpec('🍽 BITES', AppColors.primary),
    StyleBiteStickerSpec('🍕 PLATE', Color(0xFFFDCB6E)),
    StyleBiteStickerSpec('💅 DRIP', Color(0xFF0984E3)),
    StyleBiteStickerSpec('🌙 MOOD', Color(0xFF74B9FF)),
    StyleBiteStickerSpec('🌶 SPICY', Color(0xFFE17055)),
    StyleBiteStickerSpec('🤍 CLEAN', Color(0xFFDFE6E9), darkText: true),
    StyleBiteStickerSpec('🌃 NIGHT', Color(0xFF2D3436)),
    StyleBiteStickerSpec('👨‍🍳 CHEF KISS', Color(0xFFE67E22)),
    StyleBiteStickerSpec('☁️ SOFT LIFE', Color(0xFFFD79A8)),
    StyleBiteStickerSpec('🛍 STREET', Color(0xFF2D3436)),
    StyleBiteStickerSpec('🥂 BRUNCH', Color(0xFFFAB1A0)),
    StyleBiteStickerSpec('💯 SLAY', Color(0xFFE84393)),
    StyleBiteStickerSpec('👑 MAIN', Color(0xFFF1C40F)),
    StyleBiteStickerSpec('💫 VIBES', Color(0xFFA29BFE)),
    StyleBiteStickerSpec('🦋 SOFT', Color(0xFF81ECEC)),
    StyleBiteStickerSpec('🔥 TRENDING', Color(0xFFFF7675)),
    StyleBiteStickerSpec('🍓 SWEET', Color(0xFFFF7675)),
    StyleBiteStickerSpec('STYLEBITE', AppColors.primary),
  ];

  static Widget builder(
    void Function(WidgetLayer layer) setLayer,
    ScrollController scrollController,
  ) {
    return Material(
      color: StyleBiteEditorChrome.bar,
      child: GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemCount: _pack.length,
        itemBuilder: (context, index) {
          final spec = _pack[index];
          return GestureDetector(
            onTap: () {
              setLayer(
                WidgetLayer(
                  widget: StyleBiteStoryStickerChip(spec: spec),
                  exportConfigs: WidgetLayerExportConfigs(
                    id: 'sb-sticker-${spec.label}',
                  ),
                ),
              );
            },
            child: StyleBiteStoryStickerChip(spec: spec),
          );
        },
      ),
    );
  }
}

class StyleBiteStickerSpec {
  const StyleBiteStickerSpec(this.label, this.color, {this.darkText = false});

  final String label;
  final Color color;
  final bool darkText;
}

class StyleBiteStoryStickerChip extends StatelessWidget {
  const StyleBiteStoryStickerChip({super.key, required this.spec});

  final StyleBiteStickerSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: spec.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        spec.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppFonts.plusJakarta(
          size: 13,
          weight: FontWeight.w800,
          color: spec.darkText ? const Color(0xFF1A1A1A) : Colors.white,
        ),
      ),
    );
  }
}
