import 'package:Bloomee/blocs/social/friends_cubit.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Bloomee/blocs/social/requests_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Bloomee/services/social/now_playing_service.dart';
import 'package:Bloomee/services/audio_service_initializer.dart';
import 'package:audio_service/audio_service.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _PlayingBars extends StatefulWidget {
  const _PlayingBars({this.size = 18, this.color = Colors.greenAccent});
  final double size;
  final Color color;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars> with TickerProviderStateMixin {
  late final AnimationController _c1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  late final AnimationController _c2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true);
  late final AnimationController _c3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  late final Animation<double> _a1 = CurvedAnimation(parent: _c1, curve: Curves.easeInOut);
  late final Animation<double> _a2 = CurvedAnimation(parent: _c2, curve: Curves.easeInOut);
  late final Animation<double> _a3 = CurvedAnimation(parent: _c3, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final barWidth = w / 5; // three bars with small gaps
    final maxH = w;
    final minH = w * 0.35;
    return SizedBox(
      width: w,
      height: maxH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(_a1, barWidth, minH, maxH),
          SizedBox(width: barWidth * 0.5),
          _bar(_a2, barWidth, minH, maxH),
          SizedBox(width: barWidth * 0.5),
          _bar(_a3, barWidth, minH, maxH),
        ],
      ),
    );
  }

  Widget _bar(Animation<double> a, double bw, double minH, double maxH) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) {
        final h = minH + (maxH - minH) * a.value;
        return Container(
          width: bw,
          height: h,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(bw / 2),
          ),
        );
      },
    );
  }
}

class _FriendsPageState extends State<FriendsPage> {
  final _controller = TextEditingController();
  late final NowPlayingService _npService = NowPlayingService(Supabase.instance.client);
  String? _expandedFriendId;

  String _resolveAvatar(String urlOrPath) {
    if (urlOrPath.isEmpty) return '';
    if (urlOrPath.startsWith('http')) return urlOrPath;
    try {
      return Supabase.instance.client.storage.from('avatars').getPublicUrl(urlOrPath);
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<FriendsCubit>().loadFriends();
    context.read<RequestsCubit>().loadBoth();
    _npService.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _npService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Default_Theme.themeColor,
        surfaceTintColor: Default_Theme.themeColor,
      ),
      backgroundColor: Default_Theme.themeColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Search by username...',
                      isDense: true,
                      filled: true,
                      fillColor: Default_Theme.primaryColor2.withOpacity(0.06),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Default_Theme.primaryColor1.withOpacity(0.12)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Default_Theme.primaryColor1.withOpacity(0.12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Default_Theme.accentColor2.withOpacity(0.7)),
                      ),
                    ),
                    onSubmitted: (v) => context.read<FriendsCubit>().search(v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => context.read<FriendsCubit>().search(_controller.text),
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: MultiBlocListener(
                listeners: [
                  BlocListener<RequestsCubit, RequestsState>(
                    listenWhen: (prev, curr) => prev.requests.length != curr.requests.length,
                    listener: (context, state) {
                      // When a request is accepted/declined, refresh friends
                      context.read<FriendsCubit>().loadFriends();
                    },
                  ),
                ],
                child: RefreshIndicator(
                  triggerMode: RefreshIndicatorTriggerMode.anywhere,
                  backgroundColor: Default_Theme.themeColor,
                  color: Default_Theme.accentColor2,
                  displacement: 24,
                  edgeOffset: 0,
                  onRefresh: () async {
                    await context.read<FriendsCubit>().loadFriends();
                    await context.read<RequestsCubit>().loadBoth();
                  },
                  child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search results section
                      BlocBuilder<FriendsCubit, FriendsState>(
                        builder: (context, state) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (state.searchLoading)
                                const ListTile(title: Text('Searching...')),
                              if (!state.searchLoading && state.results.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text('Results'),
                                ),
                              ...state.results.map((u) {
                              final avatar = _resolveAvatar((u['avatar_url'] ?? '') as String);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Default_Theme.primaryColor2.withOpacity(0.2),
                                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                  child: avatar.isEmpty ? const Icon(Icons.person) : null,
                                ),
                                title: Text(u['username'] ?? ''),
                                subtitle: Text(u['id'] ?? ''),
                                trailing: Builder(builder: (context) {
                                  final uid = u['id'] as String;
                                  final already = state.requestedIds.contains(uid);
                                  return FilledButton(
                                    onPressed: already ? null : () => context.read<FriendsCubit>().sendRequest(uid),
                                    child: Text(already ? 'Sent' : 'Add'),
                                  );
                                }),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Incoming friend requests section
                    BlocBuilder<RequestsCubit, RequestsState>(

                      builder: (context, rstate) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (rstate.requests.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('Friend requests', style: Default_Theme.secondoryTextStyleMedium),
                              ),
                            ...rstate.requests.map((req) {
                              final profile = (req['profiles'] as Map<String, dynamic>?) ?? {};
                              final name = (profile['username'] ?? '') as String;
                              final avatar = _resolveAvatar((profile['avatar_url'] ?? '') as String);
                              return _RequestCard(
                                name: name.isEmpty ? (req['sender_id'] as String? ?? '') : name,
                                avatarUrl: avatar,
                                accept: () => context.read<RequestsCubit>().accept(req['id'] as String, req['sender_id'] as String),
                                decline: () => context.read<RequestsCubit>().decline(req['id'] as String),
                              );
                            }),
                          ],
                        );
                      },
                    ),

                    // Sent friend requests section
                    BlocBuilder<RequestsCubit, RequestsState>(
                      builder: (context, rstate) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (rstate.sentRequests.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('Sent requests', style: Default_Theme.secondoryTextStyleMedium),
                              ),
                            ...rstate.sentRequests.map((req) {
                              final profile = (req['profiles'] as Map<String, dynamic>?) ?? {};
                              final name = (profile['username'] ?? '') as String;
                              final avatar = (profile['avatar_url'] ?? '') as String;
                              return _RequestCard(
                                name: name.isEmpty ? (req['receiver_id'] as String? ?? '') : name,
                                avatarUrl: avatar,
                                // no actions for sent (pending) requests
                                accept: null,
                                decline: null,
                                showActions: false,
                                trailing: const Text('Pending'),
                              );
                            }),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Your Friends', style: Default_Theme.secondoryTextStyleMedium),
                    ),
                    BlocBuilder<FriendsCubit, FriendsState>(
                      builder: (context, state) {
                        if (state.loading) {
                          return const ListTile(title: Text('Loading friends...'));
                        }
                        return Column(
                          children: [
                            ...state.friends.map((f) {
                              final profile = f['profiles'] as Map<String, dynamic>?;
                              final name = profile != null ? (profile['username'] ?? '') : (f['friend_id'] ?? '');
                              final avatar = profile != null ? _resolveAvatar((profile['avatar_url'] ?? '') as String) : '';
                              final uid = (f['friend_id'] ?? f['id'] ?? '') as String? ?? '';
                              final np = uid.isNotEmpty ? state.nowPlayingByUserId[uid] : null;
                              DateTime? updated;
                              final updatedRaw = np != null ? np['updated_at'] : null;
                              if (updatedRaw is String) {
                                updated = DateTime.tryParse(updatedRaw);
                              } else if (updatedRaw is DateTime) {
                                updated = updatedRaw;
                              }
                              final isFresh = updated != null && DateTime.now().difference(updated) < const Duration(seconds: 60);
                              final playing = isFresh && (np != null && np['is_playing'] == true);
                              final showTitle = isFresh && np != null && (np['title'] ?? '').toString().isNotEmpty;
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Default_Theme.primaryColor2.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Default_Theme.primaryColor1.withOpacity(0.10)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Default_Theme.primaryColor2.withOpacity(0.2),
                                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                            child: avatar.isEmpty ? const Icon(Icons.person_outline) : null,
                                          ),
                                          Positioned(
                                            bottom: -1,
                                            right: -1,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: isFresh ? Colors.greenAccent : Colors.grey,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(name, style: Default_Theme.secondoryTextStyleMedium),
                                      subtitle: showTitle ? Text('${np['title'] ?? ''} • ${np['artist'] ?? ''}') : null,
                                      trailing: playing ? const _PlayingBars(size: 18, color: Colors.greenAccent) : null,
                                      onTap: () {
                                        setState(() {
                                          _expandedFriendId = _expandedFriendId == uid ? null : uid;
                                        });
                                      },
                                    ),
                                    AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 200),
                                      crossFadeState: _expandedFriendId == uid ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Default_Theme.primaryColor2.withOpacity(0.03),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Default_Theme.primaryColor1.withOpacity(0.08),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (playing && (np['track_id'] as String?)?.isNotEmpty == true)
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Default_Theme.accentColor2.withOpacity(0.15),
                                                      Default_Theme.accentColor1.withOpacity(0.15),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(10),
                                                    onTap: () async {
                                                    setState(() {
                                                      _expandedFriendId = null;
                                                    });
                                                    try {
                                                      final trackId = np['track_id'] as String?;
                                                      final title = np['title'] as String? ?? 'Unknown';
                                                      final artist = np['artist'] as String? ?? 'Unknown';
                                                      final artworkUrl = np['artwork_url'] as String? ?? '';
                                                      
                                                      if (trackId == null || trackId.isEmpty) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Track-ID nicht verfügbar')),
                                                        );
                                                        return;
                                                      }

                                                      final player = await PlayerInitializer().getBloomeeMusicPlayer();
                                                      
                                                      // Create MediaItem from friend's track
                                                      final mediaItem = MediaItem(
                                                        id: trackId,
                                                        title: title,
                                                        artist: artist,
                                                        artUri: Uri.parse(artworkUrl),
                                                        extras: np['extras'] as Map<String, dynamic>? ?? {},
                                                      );
                                                      
                                                      // Play immediately by adding to front of queue
                                                      await player.addPlayNextItem(mediaItem);
                                                      await player.skipToNext();
                                                      
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Spiele jetzt: $title')),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Fehler: $e')),
                                                      );
                                                    }
                                                  },
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.play_arrow_rounded,
                                                            color: Default_Theme.accentColor2,
                                                            size: 22,
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            'Play Song',
                                                            style: Default_Theme.secondoryTextStyleMedium.merge(
                                                              TextStyle(
                                                                color: Default_Theme.accentColor2,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (playing && (np['track_id'] as String?)?.isNotEmpty == true)
                                              const SizedBox(height: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.redAccent.withOpacity(0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(10),
                                                  onTap: () async {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Freund entfernen?'),
                                                      content: Text('Möchtest du $name entfernen?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                                                        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Entfernen')),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmed == true) {
                                                    setState(() {
                                                      _expandedFriendId = null;
                                                    });
                                                    context.read<FriendsCubit>().removeFriend(uid);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('$name wurde entfernt')),
                                                    );
                                                  }
                                                },
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          Icons.person_remove_alt_1_outlined,
                                                          color: Colors.redAccent,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'Remove Friend',
                                                          style: Default_Theme.secondoryTextStyleMedium.merge(
                                                            const TextStyle(
                                                              color: Colors.redAccent,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    ),
  );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.name,
    required this.avatarUrl,
    this.accept,
    this.decline,
    this.showActions = true,
    this.trailing,
  });
  final String name;
  final String avatarUrl;
  final VoidCallback? accept;
  final VoidCallback? decline;
  final bool showActions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Default_Theme.primaryColor2.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Default_Theme.primaryColor1.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Default_Theme.primaryColor2.withOpacity(0.2),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 28) : null,
          ),
          const SizedBox(height: 10),
          Text(name, style: Default_Theme.secondoryTextStyleMedium),
          const SizedBox(height: 10),
          if (showActions)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.greenAccent.shade400, foregroundColor: Colors.black),
                  onPressed: accept,
                  child: const Text('ACCEPT'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent.shade200, foregroundColor: Colors.black),
                  onPressed: decline,
                  child: const Text('DECLINE'),
                ),
              ],
            )
          else if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: trailing!,
            ),
        ],
      ),
    );
  }
}
