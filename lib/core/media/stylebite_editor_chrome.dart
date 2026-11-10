import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'stylebite_background_blur_sheet.dart';

/// Instagram-clean StyleBite chrome.
/// Bottom = Filter | Edit only (no duplicate / overflow).
/// Top = Cancel · tools · Lux · Next.
class StyleBiteEditorChrome {
  StyleBiteEditorChrome._();

  /// Soft rose-charcoal — StyleBite studio (not pure black).
  static const Color canvas = Color(0xFF1A1517);
  static const Color bar = Color(0xFF241C20);
  static const Color elevated = Color(0xFF2E2429);
  static const Color muted = Color(0xFFD4C6CB);
  static const Color hairline = Color(0x33FF4D6D);

  static MainEditorWidgets main({
    required bool storyTools,
    required bool forVideo,
    bool hideFilters = false,
  }) {
    return MainEditorWidgets(
      appBar: (editor, rebuildStream) => ReactiveAppbar(
        stream: rebuildStream,
        builder: (_) => _IgAppBar(
          storyTools: storyTools,
          forVideo: forVideo,
          canUndo: editor.canUndo,
          canRedo: editor.canRedo,
          onClose: editor.closeEditor,
          onDone: editor.doneEditing,
          onUndo: editor.undoAction,
          onRedo: editor.redoAction,
          onLux: editor.openTuneEditor,
          onCrop: editor.openCropRotateEditor,
          onText: editor.openTextEditor,
          onStickers: editor.openStickerEditor,
          onDraw: editor.openPaintEditor,
          onBlur: () => showStyleBiteBackgroundBlur(editor.context, editor),
          doneLabel: forVideo ? 'Done' : 'Next',
        ),
      ),
      bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => hideFilters
            ? _IgEditOnlyBar(
                key: key,
                onEdit: editor.openTuneEditor,
              )
            : _IgFilterEditTabs(
                key: key,
                onFilters: editor.openFilterEditor,
                onEdit: editor.openTuneEditor,
              ),
      ),
    );
  }

  /// Circular filter chips like Instagram's filter strip.
  static Widget filterButton({
    required FilterModel filter,
    required bool isSelected,
    required double? scaleFactor,
    required VoidCallback onSelectFilter,
    required Widget editorImage,
    required Key filterKey,
  }) {
    return Transform.scale(
      scale: scaleFactor ?? 1,
      child: GestureDetector(
        key: filterKey,
        onTap: onSelectFilter,
        child: SizedBox(
          width: 78,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 70,
                height: 70,
                padding: EdgeInsets.all(isSelected ? 2.5 : 1.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        )
                      : null,
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.white24, width: 1),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(child: editorImage),
              ),
              const SizedBox(height: 7),
              Text(
                filter.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppFonts.plusJakarta(
                  size: 11,
                  weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IgAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _IgAppBar({
    required this.storyTools,
    required this.forVideo,
    required this.canUndo,
    required this.canRedo,
    required this.onClose,
    required this.onDone,
    required this.onUndo,
    required this.onRedo,
    required this.onLux,
    required this.onCrop,
    required this.onText,
    required this.onStickers,
    required this.onDraw,
    required this.onBlur,
    required this.doneLabel,
  });

  final bool storyTools;
  final bool forVideo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onClose;
  final VoidCallback onDone;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onLux;
  final VoidCallback onCrop;
  final VoidCallback onText;
  final VoidCallback onStickers;
  final VoidCallback onDraw;
  final VoidCallback onBlur;
  final String doneLabel;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StyleBiteEditorChrome.canvas,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 40),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppFonts.plusJakarta(
                      size: 16,
                      weight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
                const Spacer(),
                _TopIcon(
                  icon: Icons.crop_rotate_rounded,
                  tooltip: 'Crop',
                  onTap: onCrop,
                ),
                if (!forVideo)
                  _TopIcon(
                    icon: Icons.blur_on_rounded,
                    tooltip: 'Background blur',
                    onTap: onBlur,
                  ),
                if (storyTools) ...[
                  _TopIcon(
                    icon: Icons.text_fields_rounded,
                    tooltip: 'Text',
                    onTap: onText,
                  ),
                  _TopIcon(
                    icon: Icons.sticky_note_2_outlined,
                    tooltip: 'Stickers',
                    onTap: onStickers,
                  ),
                  _TopIcon(
                    icon: Icons.brush_rounded,
                    tooltip: 'Draw',
                    onTap: onDraw,
                  ),
                ],
                _TopIcon(
                  icon: Icons.wb_sunny_outlined,
                  tooltip: 'Lux',
                  onTap: onLux,
                  color: AppColors.accent,
                ),
                _TopIcon(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  enabled: canUndo,
                  onTap: onUndo,
                ),
                _TopIcon(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: canRedo,
                  onTap: onRedo,
                ),
                TextButton(
                  onPressed: onDone,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 40),
                  ),
                  child: Text(
                    doneLabel,
                    style: AppFonts.plusJakarta(
                      size: 16,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.enabled = true,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        icon,
        size: 22,
        color: enabled
            ? (color ?? Colors.white.withValues(alpha: 0.88))
            : Colors.white24,
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

enum _MainTab { filter, edit }

/// Bottom dock when a look was already baked (Flash) — Edit only.
class _IgEditOnlyBar extends StatelessWidget {
  const _IgEditOnlyBar({
    super.key,
    required this.onEdit,
  });

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: StyleBiteEditorChrome.bar,
      child: SizedBox(
        height: 56 + bottomInset,
        child: Column(
          children: [
            Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    StyleBiteEditorChrome.hairline,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _PrimaryTab(
                  label: 'Edit',
                  selected: true,
                  onTap: onEdit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean Instagram bottom: Filter | Edit only — no overflow, no half tools.
class _IgFilterEditTabs extends StatefulWidget {
  const _IgFilterEditTabs({
    super.key,
    required this.onFilters,
    required this.onEdit,
  });

  final VoidCallback onFilters;
  final VoidCallback onEdit;

  @override
  State<_IgFilterEditTabs> createState() => _IgFilterEditTabsState();
}

class _IgFilterEditTabsState extends State<_IgFilterEditTabs> {
  _MainTab _tab = _MainTab.filter;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: StyleBiteEditorChrome.bar,
      child: SizedBox(
        // Fixed height so ProImageEditor never overflows the dock.
        height: 56 + bottomInset,
        child: Column(
          children: [
            Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    StyleBiteEditorChrome.hairline,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Row(
                  children: [
                    Expanded(
                      child: _PrimaryTab(
                        label: 'Filter',
                        selected: _tab == _MainTab.filter,
                        onTap: () {
                          setState(() => _tab = _MainTab.filter);
                          widget.onFilters();
                        },
                      ),
                    ),
                    Expanded(
                      child: _PrimaryTab(
                        label: 'Edit',
                        selected: _tab == _MainTab.edit,
                        onTap: () {
                          setState(() => _tab = _MainTab.edit);
                          widget.onEdit();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryTab extends StatelessWidget {
  const _PrimaryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w700,
              color: selected ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 2.5,
            width: selected ? 56 : 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: selected
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    )
                  : null,
              color: selected ? null : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
