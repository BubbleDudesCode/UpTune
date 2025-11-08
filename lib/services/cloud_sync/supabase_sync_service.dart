import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncService {
  SupabaseSyncService._();
  static final SupabaseSyncService instance = SupabaseSyncService._();
  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;
  String? get currentUserId => _uid;

  Future<List<Map<String, dynamic>>> fetchPlaylists() async {
    if (_uid == null) return [];
    final res = await _client
        .from('playlists')
        .select()
        .order('updated_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchPlaylistItems(String playlistId) async {
    if (_uid == null) return [];
    final res = await _client
        .from('playlist_items')
        .select()
        .eq('playlist_id', playlistId)
        .order('updated_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchLikes() async {
    if (_uid == null) return [];
    final res = await _client
        .from('likes')
        .select()
        .order('updated_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<String?> upsertPlaylist({String? id, required String name, String? coverUrl}) async {
    if (_uid == null) return null;
    final payload = {
      if (id != null) 'id': id,
      'user_id': _uid,
      'name': name,
      'cover_url': coverUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client.from('playlists').upsert(payload).select('id').maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> deletePlaylist(String id) async {
    if (_uid == null) return;
    await _client.from('playlists').delete().eq('id', id);
  }

  Future<void> addPlaylistItem({
    required String playlistId,
    required String songId,
    String? title,
    String? artist,
    String? imageUrl,
    String? provider,
    Map<String, dynamic>? metadata,
  }) async {
    if (_uid == null) return;
    final payload = {
      'user_id': _uid,
      'playlist_id': playlistId,
      'song_id': songId,
      'title': title,
      'artist': artist,
      'image_url': imageUrl,
      'provider': provider,
      'metadata': metadata,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('playlist_items').insert(payload);
  }

  Future<void> removePlaylistItemById(String playlistItemId) async {
    if (_uid == null) return;
    await _client.from('playlist_items').delete().eq('id', playlistItemId);
  }

  Future<void> removePlaylistItemBySong({required String playlistId, required String songId}) async {
    if (_uid == null) return;
    await _client
        .from('playlist_items')
        .delete()
        .eq('playlist_id', playlistId)
        .eq('song_id', songId);
  }

  Future<Map<String, dynamic>?> getPlaylistByName(String name) async {
    if (_uid == null) return null;
    final res = await _client
        .from('playlists')
        .select()
        .eq('name', name)
        .maybeSingle();
    if (res == null) return null;
    return (res as Map<String, dynamic>);
  }

  Future<void> likeSong({
    required String songId,
    String? title,
    String? artist,
    String? imageUrl,
    String? provider,
  }) async {
    if (_uid == null) return;
    final payload = {
      'user_id': _uid,
      'song_id': songId,
      'title': title,
      'artist': artist,
      'image_url': imageUrl,
      'provider': provider,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('likes').upsert(payload);
  }

  Future<void> unlikeSong(String songId) async {
    if (_uid == null) return;
    await _client.from('likes').delete().eq('song_id', songId);
  }

  Future<bool> isSongLiked(String songId) async {
    final uid = _uid;
    if (uid == null) return false;
    final res = await _client
        .from('likes')
        .select()
        .eq('song_id', songId)
        .eq('user_id', uid)
        .maybeSingle();
    return res != null;
  }

  // Recently Played
  Future<List<Map<String, dynamic>>> fetchRecentlyPlayed({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    final res = await _client
        .from('recently_played')
        .select()
        .eq('user_id', uid)
        .order('played_at', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> addRecentlyPlayed({
    required String songId,
    String? title,
    String? artist,
    String? imageUrl,
    String? provider,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final payload = {
      'user_id': uid,
      'song_id': songId,
      'title': title,
      'artist': artist,
      'image_url': imageUrl,
      'provider': provider,
      'metadata': metadata,
      'played_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    // Upsert with conflict resolution - newer timestamp wins
    await _client.from('recently_played').upsert(payload, 
      onConflict: 'user_id,song_id');
  }

  Future<void> clearRecentlyPlayed() async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('recently_played').delete().eq('user_id', uid);
  }
}
