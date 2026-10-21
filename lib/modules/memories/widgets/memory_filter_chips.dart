import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class MemoryFilterChips extends StatelessWidget {
  const MemoryFilterChips({
    super.key,
    required this.active,
    required this.onChanged,
  });

  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = ['all', 'favorites', 'last_week', 'last_month'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isActive = filter == active;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(filter),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: isActive
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          )
                        : null,
                    color: isActive ? null : Colors.white,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.32),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _label(filter),
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.hintText,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'favorites':
        return 'Favorites';
      case 'last_week':
        return 'Last Week';
      case 'last_month':
        return 'Last Month';
      default:
        return filter;
    }
  }
}
