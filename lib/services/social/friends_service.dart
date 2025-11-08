import 'package:supabase_flutter/supabase_flutter.dart';

class FriendsService {
  FriendsService(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query) async {
    if (query.trim().isEmpty) return [];
    final userId = client.auth.currentUser?.id;
    final res = await client
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%${query.trim()}%')
        .limit(20);
    final list = (res as List).cast<Map<String, dynamic>>();
    if (userId == null) return list;
    return list.where((e) => e['id'] != userId).toList();
  }

  Future<void> sendFriendRequest(String receiverId) async {
    final userId = client.auth.currentUser!.id;
    await client.from('friend_requests').upsert({
      'sender_id': userId,
      'receiver_id': receiverId,
      'status': 'pending',
    }, onConflict: 'sender_id,receiver_id');
  }

  Future<void> acceptRequest(String requestId, String senderId) async {
    final userId = client.auth.currentUser!.id;
    // Update request -> accepted
    await client
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
    // Insert both edges for undirected friendship
    await client.from('friends').upsert([
      {'user_id': userId, 'friend_id': senderId},
      {'user_id': senderId, 'friend_id': userId},
    ]);
  }

  Future<void> declineRequest(String requestId) async {
    await client
        .from('friend_requests')
        .update({'status': 'declined'})
        .eq('id', requestId);
  }

  Future<List<Map<String, dynamic>>> listFriends() async {
    final userId = client.auth.currentUser!.id;
    final res = await client
        .from('friends')
        .select('friend_id, profiles:friend_id (id, username, avatar_url)')
        .eq('user_id', userId)
        .order('created_at')
        .limit(100);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> removeFriend(String friendId) async {
    final userId = client.auth.currentUser!.id;
    // Delete both directions to remove friendship completely
    try {
      // Direction 1: user -> friend
      await client.from('friends')
          .delete()
          .eq('user_id', userId)
          .eq('friend_id', friendId);
      
      // Direction 2: friend -> user (may fail if RLS doesn't allow)
      await client.from('friends')
          .delete()
          .eq('user_id', friendId)
          .eq('friend_id', userId);
    } catch (e) {
      // If second delete fails due to RLS, try alternative approach
      // Delete where current user is either user_id OR friend_id
      await client.from('friends')
          .delete()
          .or('user_id.eq.$userId,friend_id.eq.$userId')
          .or('user_id.eq.$friendId,friend_id.eq.$friendId');
    }
  }

  Future<List<Map<String, dynamic>>> listIncomingRequests() async {
    final userId = client.auth.currentUser!.id;
    final res = await client
        .from('friend_requests')
        .select('id, sender_id, status, created_at, profiles:sender_id (id, username, avatar_url)')
        .eq('receiver_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listSentRequests() async {
    final userId = client.auth.currentUser!.id;
    final res = await client
        .from('friend_requests')
        .select('id, receiver_id, status, created_at, profiles:receiver_id (id, username, avatar_url)')
        .eq('sender_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).cast<Map<String, dynamic>>();
  }
}
