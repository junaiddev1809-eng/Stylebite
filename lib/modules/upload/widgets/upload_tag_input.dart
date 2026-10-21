import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';

class UploadTagInput extends StatelessWidget {
  const UploadTagInput({
    super.key,
    required this.controller,
    required this.tags,
    required this.options,
    required this.hintText,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<String> tags;
  final List<String> options;
  final String hintText;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onSubmitted: onAddTag,
            onChanged: onChanged,
            scrollPhysics: const NeverScrollableScrollPhysics(),
            style: AppFonts.beVietnam(size: 13, weight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w500,
                color: const Color(0xFF9A8F8A),
              ),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                onPressed: () => onAddTag(controller.text),
                icon: const AppHeroIconData(Icons.add_rounded,
                  color: AppColors.primary,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.hintText.withValues(alpha: 0.12),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, thickness: 0.4),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      option,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    trailing: const AppHeroIconData(Icons.add_rounded,
                      color: AppColors.primary,
                    ),
                    onTap: () => onAddTag(option),
                  );
                },
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppColors.primary.withValues(alpha: 0.14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: AppFonts.beVietnam(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => onRemoveTag(tag),
                            child: const AppHeroIconData(Icons.close_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}
