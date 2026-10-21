import 'home_battle_model.dart';
import 'home_post_model.dart';

class HomeModel {
  const HomeModel({
    required this.userAvatar,
    required this.battle,
    required this.posts,
    required this.quickActions,
  });

  final String userAvatar;
  final HomeBattleModel battle;
  final List<HomePostModel> posts;
  final List<HomeQuickAction> quickActions;
}
