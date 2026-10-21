import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../controllers/contest_controller.dart';

class ProfileContestResultsScreen extends StatefulWidget {
  const ProfileContestResultsScreen({super.key});

  @override
  State<ProfileContestResultsScreen> createState() => _ProfileContestResultsScreenState();
}

class _ProfileContestResultsScreenState extends State<ProfileContestResultsScreen> {
  late final ContestController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ContestController>();
    _controller.fetchProfileResults(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contest Results')),
      body: Obx(() {
        if (_controller.isProfileResultsLoading.value && _controller.profileResults.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () => _controller.fetchProfileResults(reset: true),
          child: ListView.builder(
            itemCount: _controller.profileResults.length,
            itemBuilder: (context, index) {
              final item = _controller.profileResults[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text('Status: ${item.statusLabel} • Rank: ${item.userRank} • Score: ${item.userScore.toStringAsFixed(1)}'),
                trailing: const AppHeroIconData(Icons.chevron_right),
                onTap: () => Get.toNamed(AppRoutes.contestDetail, arguments: {'contestId': item.id}),
              );
            },
          ),
        );
      }),
    );
  }
}
