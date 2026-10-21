import 'package:get/get.dart';

import '../../modules/auth/screen/account_restricted_screen.dart';
import '../../modules/auth/screen/forgot_password_screen.dart';
import '../../modules/auth/screen/login_screen.dart';
import '../../modules/auth/screen/otp_screen.dart';
import '../../modules/auth/screen/reset_password_screen.dart';
import '../../modules/auth/screen/signup_screen.dart';
import '../../modules/create_contest/screen/create_contest_screen.dart';
import '../../modules/earnings/screen/my_earnings_screen.dart';
import '../../modules/contest/screen/contest_detail_screen.dart';
import '../../modules/contest/screen/contest_invitations_screen.dart';
import '../../modules/contest/screen/contest_ranking_screen.dart';
import '../../modules/contest/screen/profile_contest_results_screen.dart';
import '../../modules/explore/screen/explore_screen.dart';
import '../../modules/home/screen/home_screen.dart';
import '../../modules/intro/screen/intro_screen.dart';
import '../../modules/landing/screen/landing_screen.dart';
import '../../modules/messages/screen/messages_screen.dart';
import '../../modules/profile/screen/edit_profile_screen.dart';
import '../../modules/post/screens/hashtag_feed_screen.dart';
import '../../modules/search/screen/search_screen.dart';
import '../../modules/settings/screen/about_stylebite_screen.dart';
import '../../modules/settings/screen/help_center_screen.dart';
import '../../modules/settings/screen/privacy_policy_screen.dart';
import '../../modules/splash/screen/splash_screen.dart';
import '../../modules/support/screen/new_support_ticket_screen.dart';
import '../../modules/support/screen/support_ticket_detail_screen.dart';
import '../../modules/support/screen/support_tickets_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const String initial = AppRoutes.splash;
  static const Duration _fadeDuration = Duration(milliseconds: 240);
  static const Duration _slideDuration = Duration(milliseconds: 220);

  static GetPage<dynamic> _fade(String name, GetPageBuilder page) {
    return GetPage<dynamic>(
      name: name,
      page: page,
      transition: Transition.fadeIn,
      transitionDuration: _fadeDuration,
      preventDuplicates: true,
    );
  }

  static GetPage<dynamic> _slide(String name, GetPageBuilder page) {
    return GetPage<dynamic>(
      name: name,
      page: page,
      transition: Transition.cupertino,
      transitionDuration: _slideDuration,
      popGesture: true,
      preventDuplicates: true,
    );
  }

  static final List<GetPage<dynamic>> routes = [
    _fade(AppRoutes.splash, SplashScreen.new),
    _fade(AppRoutes.intro, IntroScreen.new),
    _fade(AppRoutes.login, LoginScreen.new),
    _slide(AppRoutes.signUp, SignUpScreen.new),
    _slide(AppRoutes.otp, OtpScreen.new),
    _fade(AppRoutes.accountRestricted, AccountRestrictedScreen.new),
    _slide(AppRoutes.forgotPassword, ForgotPasswordScreen.new),
    _slide(AppRoutes.resetPassword, ResetPasswordScreen.new),
    _fade(AppRoutes.landing, LandingScreen.new),
    _fade(AppRoutes.home, HomeScreen.new),
    _slide(AppRoutes.explore, ExploreScreen.new),
    _slide(AppRoutes.search, SearchScreen.new),
    _slide(
      '${AppRoutes.hashtagFeed}/:tag',
      () => HashtagFeedScreen(
        tag: Uri.decodeComponent(Get.parameters['tag'] ?? ''),
      ),
    ),
    _slide(AppRoutes.messages, MessagesScreen.new),
    _slide(AppRoutes.editProfile, EditProfileScreen.new),
    _slide(AppRoutes.myEarnings, MyEarningsScreen.new),
    _slide(AppRoutes.createContest, CreateContestScreen.new),
    _slide(AppRoutes.contestDetail, ContestDetailScreen.new),
    _slide(AppRoutes.contestRanking, ContestRankingScreen.new),
    _slide(AppRoutes.contestInvitations, ContestInvitationsScreen.new),
    _slide(AppRoutes.profileContestResults, ProfileContestResultsScreen.new),
    _slide(AppRoutes.privacyPolicy, PrivacyPolicyScreen.new),
    _slide(AppRoutes.helpCenter, HelpCenterScreen.new),
    _slide(AppRoutes.aboutStylebite, AboutStylebiteScreen.new),
    _slide(AppRoutes.supportTickets, SupportTicketsScreen.new),
    _slide(AppRoutes.supportTicketDetail, SupportTicketDetailScreen.new),
    _slide(AppRoutes.newSupportTicket, NewSupportTicketScreen.new),
  ];
}
