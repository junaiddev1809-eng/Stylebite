import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_fonts.dart';
import '../controllers/contest_controller.dart';

class ContestInvitationsScreen extends StatefulWidget {
  const ContestInvitationsScreen({super.key});

  @override
  State<ContestInvitationsScreen> createState() => _ContestInvitationsScreenState();
}

class _ContestInvitationsScreenState extends State<ContestInvitationsScreen> {
  late final ContestController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ContestController>();
    _controller.fetchInvitations(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
      body: Obx(() {
        if (_controller.isInvitationsLoading.value && _controller.invitations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () => _controller.fetchInvitations(reset: true),
          child: ListView.builder(
            itemCount: _controller.invitations.length,
            itemBuilder: (context, index) {
              final item = _controller.invitations[index];
              return ListTile(
                title: Text(item.contestTitle),
                subtitle: Text('${item.invitationType} • ${item.status}'),
                trailing: item.isPending
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: () => _controller.respondInvitation(item.id, 'accepted'), child: const Text('Accept')),
                          TextButton(onPressed: () => _controller.respondInvitation(item.id, 'rejected'), child: const Text('Reject')),
                        ],
                      )
                    : Text(item.status.toUpperCase(), style: AppFonts.plusJakarta(size: 12, weight: FontWeight.w700)),
              );
            },
          ),
        );
      }),
    );
  }
}
