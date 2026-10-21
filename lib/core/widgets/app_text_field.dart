import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.isPassword = false,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.errorMaxLines = 2,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool isPassword;
  final int? maxLength;
  final int maxLines;
  final IconData? prefixIcon;
  final int? errorMaxLines;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppFonts.beVietnam(
            size: 13,
            weight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          obscureText: _obscureText,
          maxLength: widget.maxLength,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          style: AppFonts.beVietnam(
            size: 14,
            weight: FontWeight.w500,
            color: AppColors.text,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: AppColors.hintText.withValues(alpha: 0.8),
            ),
            counterText: '',
            prefixIcon: widget.prefixIcon == null
                ? null
                : AppHeroIconData(
                    widget.prefixIcon!,
                    color: AppColors.hintText,
                  ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    icon: AppHeroIconData(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.hintText,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.hintText.withValues(alpha: 0.18),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.hintText.withValues(alpha: 0.18),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            errorMaxLines: widget.errorMaxLines,
            errorStyle: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w500,
              color: Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }
}
