import 'package:flutter/material.dart';

class SettingsItemModel {
  const SettingsItemModel({
    required this.title,
    this.trailing,
    this.icon,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final IconData? icon;
  final VoidCallback? onTap;
}
