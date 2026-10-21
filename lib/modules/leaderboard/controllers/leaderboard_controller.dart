import 'package:get/get.dart';

import '../models/leaderboard_models.dart';

class LeaderboardController extends GetxController {
  final RxString activePeriod = 'global'.obs;
  final RxString activeCategory = 'outfit'.obs;

  late final LeaderboardContestContext contest;

  final List<LeaderboardEntry> topThree = const [
    LeaderboardEntry(
      rank: 1,
      name: 'Aria.Chic',
      handle: '@ariachic',
      points: '56.8k',
      earnings: r'$2,140',
      avatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDRUeQlYmPIPmFEme3WnzNLmgNLKxTsc3kzWYP1GyhC7QPF1-q8oMzrNB7-VZlwUvFFNgDV59pc5Zluo4JlnDF__IaNb1o3BiBwU-QMEliY1W6PT9u-twyzsTIQL2GicA5gxLQ2ikylvPajOyjhW1M0IlyOsrMxTuL_5JHfMa_gXuhMMxXXvuBI9JcX7WJj-SU4GyzNegs0dx6vWJseBIPVeRLXeFkBeU89Iu1mi5VJO7HYmehDFoAgZC463l3dNk-1o_LZ1VboT4M2',
    ),
    LeaderboardEntry(
      rank: 2,
      name: 'Julian_Vibe',
      handle: '@julianvibe',
      points: '42.1k',
      earnings: r'$1,760',
      avatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAZ7ivZRaXudso6GNdRctDwDEt4gt0O2yV3Lh6bRK8ADdyQMrGac7_CM-JarE6DD4HQhclBNUdEYmWaEWdHVGg6otFZd_gabo_wgPGcge2xwVUc59WXu69P9M2jMpty4pMbc_mMPQDmUvPeBAvFwvVtqgnmC--zaUSGfrOK4JOobwjUN4A5CnEURhQvScnDT8SV_bcBQ_JrRokb0MCPPbFiTHg2LWVSqbMRhrWYXLwygoDO5nmuypigAcjrMBwWOPjtPbmcrnIEPtlR',
    ),
    LeaderboardEntry(
      rank: 3,
      name: 'Marcus_Edge',
      handle: '@marcusedge',
      points: '38.4k',
      earnings: r'$1,180',
      avatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA6T5LbonDkAVL7NPvOsAwLE580BTfwDe5Eq8PRhdjZGgpmKtLPsSt3W4ON9pUkX71Whld9Bz_4Oq21OJ9RkzC0kYzoZkTD-vAaUG1o_H-F2aZD9RcwOQpuAMpTM3EiH_7HBRfhcLoFbaVWkXT6LJRc99Sqg07q0bzBZB34uNDg8nF8ZglvzPmm1sxSVq4Eov8EeoMaWMwKCkmKYlUuBZRwpSfS4FOguXSA9EI841dJ-phsDLwU5hEXr0_rNMmrLJzQ_-7hXAukl2UX',
    ),
  ];

  final List<LeaderboardEntry> tableEntries = const [
    LeaderboardEntry(
      rank: 4,
      name: 'Elena_Style',
      handle: '@elenasbite',
      points: '32.2k',
      earnings: r'$1,420',
      avatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCo8U1RQwmNGHyEVPapSXYWRN-4R-Yu8hQsaw2dhDilpEcc3E_DDAxk0nX9o5doH7Wdq-0mbylRRhaJJQ6ZGgGAmgzjKgi385P7Wvv-hyIXSfoZpHyTjyG8d8YbkIXZo83uv9nc3EX-JyWVGaSNZRAvSMzH1NTDFei7Hp6_bnBDSHI1bcJEBpK3KDQ1kBpuNzozLptneRLbbwUkbbETKokQUbTvBocslBzgnh9W0LBJEZdot48wSWHX-rO8x62Udq-qUjCm2JvNHQvd',
    ),
    LeaderboardEntry(
      rank: 5,
      name: 'Sasha_Flux',
      handle: '@flux_sasha',
      points: '31.8k',
      earnings: r'$1,280',
      avatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBCUVOjUpkEMgdotys5WEYdFhHEX0iDx4bU3_ErDe18OzI1eruCedKZcOWkyr-hSWngYPber39xe6OBAB_uQg-oJLE9QKtePYp29fOQma6B3Rw7FWNfCaIOwW23VuxyYE5nq5FuwWKUQG2_JtGjVDC_XqFb0_by4xmhZH7kgQ-_U9AbAVp-Z5I4PHqSBtnU-Ep64MXUPcSGL5wH7EPDnQvsoLpWvtCkspkuAoCQN-xHYdKbF2pXCXjABlN3CPDpKZXgZFUBqXIVExqE',
    ),
    LeaderboardEntry(
      rank: 6,
      name: 'Theo_Boutique',
      handle: '@theo_btq',
      points: '29.4k',
      earnings: r'$940',
      avatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCZasrvBVTUQKpxxpbGNrflCvbZ6Rto3z47NhE-kRB0Zk0mRbcKVaB-eg8AMALc7rVBqxENoKq9WHa6lC-0YdTQJyNLUi0HAp_EDhDYBq4HftCYKyv7eMO9d1hdBEn3srrs9LEuw_4p29CXMpHodzfS9EhDAtQ8mVdyR4HLlM1KaIey2gsgiXA-JsKAapZfxdcnLi6KaktJNi9L73VPrvN6Ej8pyDN2KGeX3WHoyOZQPzB0ZPCHzfp9YtA37OZ-DJb4LRL_8NKykIVA',
    ),
    LeaderboardEntry(
      rank: 7,
      name: 'Lola_Luxe',
      handle: '@lola_luxe_official',
      points: '28.1k',
      earnings: r'$820',
      avatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBE_UvKNWMRL8jAnlpV6NAjDv-DxIzJ-dWrbJMZOV2bxGIXTj3w7bqxclJzeCuJMo4gGTA4uEcIdhclx1PurVczLwnMNiGhEjan3Dxtd9ZjpPRben4-qhLpD3fTFXzpor_jhDT1Gm7bwL9JxUvJZ0E0ysR3Wfl13u-yIyx1VKBw516VO9cbKeJ0m66u5w4rwde1W-nLkkx0sx8figSMAAlBal9yVtpUgfIYKVGAVM5JpogMfPt6RD8wRxZ8La5dSkSApcNknxg82jwQ',
    ),
  ];

  static const Map<String, LeaderboardContestContext> _contestMap = {
    'admin-metropolis-minimalist': LeaderboardContestContext(
      id: 'admin-metropolis-minimalist',
      source: 'Admin-created',
      name: 'Metropolis Minimalist',
      subtitle: 'Official city battle curated by StyleBite editors.',
      format: 'City vs City',
      window: 'Ends in 14h 22m',
      status: 'Featured Live',
      heroTitle: 'New York vs Tokyo',
      heroMeta: 'Contest ends in 14h 22m | Prize Pool \$15,000',
      participants: '81,012',
      defaultPeriod: 'global',
      defaultCategory: 'outfit',
      team1Name: 'Team New York',
      team1Pct: 58,
      team2Name: 'Team Tokyo',
      team2Pct: 42,
    ),
    'admin-retro-futurism': LeaderboardContestContext(
      id: 'admin-retro-futurism',
      source: 'Admin-created',
      name: 'Retro Futurism',
      subtitle: 'Editorial-picked 1v1 with premium creator submissions.',
      format: '1v1 Duel',
      window: 'Ends in 2d 10h',
      status: 'Open Voting',
      heroTitle: 'Lexi Style vs Marcus Vibe',
      heroMeta: 'Contest ends in 2d 10h | Prize Pool \$8,000',
      participants: '39,408',
      defaultPeriod: 'weekly',
      defaultCategory: 'outfit',
    ),
    'community-boho-group': LeaderboardContestContext(
      id: 'community-boho-group',
      source: 'Community-created',
      name: 'Boho-Chic Essentials',
      subtitle: 'Group vs group battle decided by total team votes.',
      format: 'Group vs Group',
      window: 'Ends in 4h',
      status: 'Live Voting',
      heroTitle: 'Group Aurora vs Group Nova',
      heroMeta: 'Contest ends in 4h | Prize Pool \$3,500',
      participants: '24,106',
      defaultPeriod: 'weekly',
      defaultCategory: 'battles',
      team1Name: 'Group Aurora',
      team1Pct: 52,
      team2Name: 'Group Nova',
      team2Pct: 48,
    ),
    'community-denim-brand': LeaderboardContestContext(
      id: 'community-denim-brand',
      source: 'Community-created',
      name: 'Denim Mastery',
      subtitle:
          'Brand-sponsored 1v1v1v1 contest with jury + community scoring.',
      format: 'Brand 1v1v1v1',
      window: 'Ends in 12h',
      status: 'Sponsored Live',
      heroTitle: '4-way creator invitational',
      heroMeta: 'Contest ends in 12h | Prize Pool \$12,000',
      participants: '33,920',
      defaultPeriod: 'weekly',
      defaultCategory: 'outfit',
    ),
  };

  static const LeaderboardContestContext _fallback = LeaderboardContestContext(
    id: 'metropolis-faceoff',
    source: 'Admin-created',
    name: 'Metropolis Face-Off',
    subtitle: 'Live standings for active city battle and creator performance.',
    format: 'City vs City',
    window: 'Ends in 14h 22m',
    status: 'Live Voting',
    heroTitle: 'NYC vs Tokyo',
    heroMeta: 'Contest ends in 14h 22m | Prize Pool \$15,000',
    participants: '81,012',
    defaultPeriod: 'city',
    defaultCategory: 'battles',
    team1Name: 'Team New York',
    team1Pct: 58,
    team2Name: 'Team Tokyo',
    team2Pct: 42,
  );

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    final contestId = args is Map ? args['contestId'] as String? : null;

    contest = _contestMap[contestId] ?? _fallback;
    activePeriod.value = contest.defaultPeriod;
    activeCategory.value = contest.defaultCategory;
  }

  void setPeriod(String period) {
    activePeriod.value = period;
  }

  void setCategory(String category) {
    activeCategory.value = category;
  }
}
