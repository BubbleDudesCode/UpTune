import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/services/social/friends_service.dart';
import 'dart:async';

part 'friends_state.dart';

class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit() : super(const FriendsState());

  final FriendsService _svc = FriendsService(Supabase.instance.client);
  RealtimeChannel? _npChannel;
  Set<String> _friendIds = {};

  Future<void> loadFriends() async {
    emit(state.copyWith(loading: true));
    try {
      final list = await _svc.listFriends();
      emit(state.copyWith(loading: false, friends: list));

      // Build friend ids set
      _friendIds = list
          .map<String>((f) => (f['friend_id'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Initial fetch of now playing
      await _fetchFriendsNowPlaying();

      // Subscribe realtime
      _subscribeNowPlaying();
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> removeFriend(String friendId) async {
    // Optimistic UI: remove from current list immediately
    final original = List<Map<String, dynamic>>.from(state.friends);
    final filtered = original.where((f) => f['friend_id'] != friendId).toList();
    emit(state.copyWith(friends: filtered));
    try {
      await _svc.removeFriend(friendId);
      // Reload to ensure consistency
      await loadFriends();
    } catch (e) {
      // Revert on failure
      emit(state.copyWith(error: e.toString(), friends: original));
    }
  }

  Future<void> search(String query) async {
    emit(state.copyWith(searchLoading: true, query: query));
    try {
      final results = await _svc.searchUsersByUsername(query);
      emit(state.copyWith(searchLoading: false, results: results));
    } catch (e) {
      emit(state.copyWith(searchLoading: false, error: e.toString()));
    }
  }

  Future<void> sendRequest(String receiverId) async {
    // Optimistic UI: mark as requested
    final newSet = {...state.requestedIds}..add(receiverId);
    emit(state.copyWith(requestedIds: newSet));
    try {
      await _svc.sendFriendRequest(receiverId);
      SnackbarService.showMessage("Friend request sent");
    } catch (e) {
      final reverted = {...state.requestedIds}..remove(receiverId);
      emit(state.copyWith(error: e.toString(), requestedIds: reverted));
      SnackbarService.showMessage("Failed to send request: ${e.toString()}");
    }
  }

  Future<void> _fetchFriendsNowPlaying() async {
    if (_friendIds.isEmpty) return;
    try {
      final ids = _friendIds.toList();
      final quoted = ids.map((e) => '"$e"').join(',');
      final arg = '($quoted)';
      final rows = await Supabase.instance.client
          .from('now_playing')
          .select('*')
          .filter('user_id', 'in', arg);
      final List<dynamic> list = rows as List<dynamic>;
      final map = <String, Map<String, dynamic>>{};
      for (final r in list) {
        final uid = r['user_id'] as String?;
        if (uid != null) map[uid] = r;
      }
      emit(state.copyWith(nowPlayingByUserId: map));
    } catch (e) {
      // don't fail UI, just log error into state
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _subscribeNowPlaying() {
    // Clean previous
    if (_npChannel != null) {
      Supabase.instance.client.removeChannel(_npChannel!);
      _npChannel = null;
    }

    _npChannel = Supabase.instance.client
        .channel('now_playing:friends')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'now_playing',
          callback: (payload) {
            final row = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final uid = row['user_id'] as String?;
            if (uid == null || !_friendIds.contains(uid)) return;

            final current = Map<String, Map<String, dynamic>>.from(state.nowPlayingByUserId);
            if (payload.eventType == PostgresChangeEvent.delete) {
              current.remove(uid);
            } else {
              current[uid] = row;
            }
            emit(state.copyWith(nowPlayingByUserId: current));
          },
        )
        .subscribe();
  }

  @override
  Future<void> close() async {
    try {
      if (_npChannel != null) {
        Supabase.instance.client.removeChannel(_npChannel!);
        _npChannel = null;
      }
    } catch (_) {}
    return super.close();
  }
}
