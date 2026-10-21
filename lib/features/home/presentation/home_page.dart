import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Home Page',
          style: AppFonts.plusJakarta(
            size: 28,
            weight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}
