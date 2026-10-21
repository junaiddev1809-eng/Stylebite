import 'package:heroicons/heroicons.dart';

class LandingTabModel {
  const LandingTabModel({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final dynamic icon;
  final dynamic activeIcon;

  static const List<LandingTabModel> defaultTabs = [
    LandingTabModel(
      label: 'Home',
      icon: HeroIcons.home,
      activeIcon: HeroIcons.home,
    ),
    LandingTabModel(
      label: 'Reel',
      icon: HeroIcons.play,
      activeIcon: HeroIcons.play,
    ),
    LandingTabModel(
      label: 'Upload',
      icon: HeroIcons.plus,
      activeIcon: HeroIcons.plus,
    ),
    LandingTabModel(
      label: 'Contest',
      icon: HeroIcons.bolt,
      activeIcon: HeroIcons.bolt,
    ),
    LandingTabModel(
      label: 'Profile',
      icon: HeroIcons.user,
      activeIcon: HeroIcons.user,
    ),
  ];
}
