import 'package:flutter/material.dart';

class IntroStepModel {
  const IntroStepModel({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
