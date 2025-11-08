import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Bloomee/services/social/friends_service.dart';

part 'requests_state.dart';

class RequestsCubit extends Cubit<RequestsState> {
  RequestsCubit() : super(const RequestsState()) {
    _setupRealtime();
    // Load initial pending/sent requests so we can compare lengths and notify on new ones
    loadBoth();
  }

  final FriendsService _svc = FriendsService(Supabase.instance.client);
  RealtimeChannel? _channel;

  void _setupRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('friend_requests_${uid.substring(0, 8)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) {
            final Map<String, dynamic>? newRow = payload.newRecord;
            final Map<String, dynamic>? oldRow = payload.oldRecord;
            final affected = (newRow?['receiver_id'] == uid) || (oldRow?['receiver_id'] == uid) ||
                (newRow?['sender_id'] == uid) || (oldRow?['sender_id'] == uid);
            if (affected) {
              loadBoth();
            }
          },
        )
        .subscribe();
  }

  Future<void> loadBoth() async {
    emit(state.copyWith(loading: true));
    try {
      final incoming = await _svc.listIncomingRequests();
      final sent = await _svc.listSentRequests();
      emit(state.copyWith(loading: false, requests: incoming, sentRequests: sent));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> accept(String requestId, String senderId) async {
    try {
      await _svc.acceptRequest(requestId, senderId);
      await loadBoth();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> decline(String requestId) async {
    try {
      await _svc.declineRequest(requestId);
      await loadBoth();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _channel?.unsubscribe();
    return super.close();
  }
}
