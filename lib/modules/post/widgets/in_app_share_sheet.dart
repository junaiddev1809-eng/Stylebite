import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../messages/models/chat_models.dart';
import '../../messages/services/chat_api_service.dart';
import '../../search/models/search_user_model.dart';
import '../utils/in_app_share.dart';
import '../utils/post_share_helper.dart';

class InAppShareSheet {
  const InAppShareSheet._();

  /// `direct_message` when sent inside StyleBite, `external` when shared
  /// outside, or null when the sheet closed without a share.
  static Future<String?> open({
    required BuildContext context,
    required InAppSharePayload payload,
  }) async {
    final shared = _SharedFlag();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _InAppShareSheetBody(payload: payload, shared: shared);
      },
    );
    if (shared.inApp) {
      return 'direct_message';
    }
    if (shared.outside) {
      return 'external';
    }
    return null;
  }
}

class _SharedFlag {
  bool inApp = false;
  bool outside = false;
}

class _SharePerson {
  const _SharePerson({
    required this.username,
    required this.name,
    required this.avatarUrl,
  });

  final String username;
  final String name;
  final String avatarUrl;
}

class _InAppShareSheetBody extends StatefulWidget {
  const _InAppShareSheetBody({required this.payload, required this.shared});

  final InAppSharePayload payload;
  final _SharedFlag shared;

  @override
  State<_InAppShareSheetBody> createState() => _InAppShareSheetBodyState();
}

class _InAppShareSheetBodyState extends State<_InAppShareSheetBody> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _sending = <String>{};
  final Set<String> _sent = <String>{};
  Timer? _debounce;
  List<_SharePerson> _people = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final response = await const ChatApiService().getChats();
      if (!mounted) {
        return;
      }
      setState(() {
        _people = _withoutMe(_peopleFromChats(response.chats));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  List<_SharePerson> _peopleFromChats(List<ChatThreadModel> threads) {
    final people = <_SharePerson>[];
    final seen = <String>{};
    for (final thread in threads) {
      final username = thread.user.username.trim().replaceFirst('@', '');
      if (username.isEmpty || !seen.add(username.toLowerCase())) {
        continue;
      }
      people.add(
        _SharePerson(
          username: username,
          name: thread.user.displayName,
          avatarUrl: thread.user.imageUrl,
        ),
      );
    }
    return people;
  }

  List<_SharePerson> _withoutMe(List<_SharePerson> people) {
    final me = LocalStorage.getUsername()?.trim().replaceFirst('@', '').toLowerCase();
    if (me == null || me.isEmpty) {
      return people;
    }
    return people
        .where((person) => person.username.toLowerCase() != me)
        .toList(growable: false);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _searchPeople(value);
    });
  }

  Future<void> _searchPeople(String raw) async {
    final query = raw.trim().replaceFirst(RegExp(r'^@+'), '');
    _query = query;
    if (query.isEmpty) {
      await _loadChats();
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'users/search?page=1&per_page=20&q=${Uri.encodeQueryComponent(query)}'
        '&query=${Uri.encodeQueryComponent(query)}'
        '&search=${Uri.encodeQueryComponent(query)}',
      );
      if (!mounted || _query != query) {
        return;
      }
      if (response == null) {
        setState(() => _loading = false);
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final users = SearchUsersResponseModel.fromJson(payload).users;
      setState(() {
        _people = _withoutMe(
          users
              .where((user) => user.username.trim().isNotEmpty)
              .map(
                (user) => _SharePerson(
                  username: user.username.trim().replaceFirst('@', ''),
                  name: user.title,
                  avatarUrl: user.avatarUrl,
                ),
              )
              .toList(growable: false),
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _query != query) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _send(_SharePerson person) async {
    final key = person.username.toLowerCase();
    if (_sending.contains(key) || _sent.contains(key)) {
      return;
    }
    setState(() => _sending.add(key));
    try {
      await InAppSharePayload.sendToUsername(
        username: person.username,
        payload: widget.payload,
      );
      if (!mounted) {
        return;
      }
      widget.shared.inApp = true;
      setState(() => _sent.add(key));
      successSnackBar(message: 'Sent to ${person.name}');
    } on ChatApiException catch (error) {
      if (!mounted) {
        return;
      }
      errorSnackBar(message: error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      errorSnackBar(message: 'Unable to send this right now.');
    } finally {
      if (mounted) {
        setState(() => _sending.remove(key));
      }
    }
  }

  Future<void> _shareOutside() async {
    final didShare = await PostShareHelper.shareText(
      caption: widget.payload.caption,
      link: PostShareHelper.postLink(widget.payload.id),
      username: widget.payload.username,
      subject: widget.payload.isReel
          ? 'Check out this reel'
          : 'Check out this post',
    );
    if (didShare) {
      widget.shared.outside = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D6D3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.payload.isReel ? 'Send reel' : 'Send post',
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: AppFonts.beVietnam(weight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search people',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildList()),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareOutside,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share outside StyleBite'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFE0D6D3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_people.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'No chats yet. Search a username to send this.'
              : 'No people found.',
          textAlign: TextAlign.center,
          style: AppFonts.beVietnam(
            size: 13,
            weight: FontWeight.w600,
            color: AppColors.hintText,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final person = _people[index];
        final key = person.username.toLowerCase();
        final sending = _sending.contains(key);
        final sent = _sent.contains(key);
        return Row(
          children: [
            ClipOval(
              child: person.avatarUrl.trim().isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF1EBE8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: AppHeroIconData(
                          Icons.person_rounded,
                          color: AppColors.hintText,
                          size: 20,
                        ),
                      ),
                    )
                  : AppCachedImage(
                      imageUrl: person.avatarUrl,
                      width: 44,
                      height: 44,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.plusJakarta(
                      size: 14,
                      weight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '@${person.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: sending || sent ? null : () => _send(person),
              style: FilledButton.styleFrom(
                backgroundColor: sent
                    ? const Color(0xFFEAF8EF)
                    : AppColors.primary,
                foregroundColor: sent
                    ? const Color(0xFF16A34A)
                    : Colors.white,
                disabledBackgroundColor: sent
                    ? const Color(0xFFEAF8EF)
                    : AppColors.primary.withValues(alpha: 0.5),
                disabledForegroundColor: sent
                    ? const Color(0xFF16A34A)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(sent ? 'Sent' : 'Send'),
            ),
          ],
        );
      },
    );
  }
}
