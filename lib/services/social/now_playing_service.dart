import 'dart:async';
import 'package:Bloomee/services/audio_service_initializer.dart';
import 'package:Bloomee/services/bloomeePlayer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NowPlayingService {
  NowPlayingService(this._supabase);

  final SupabaseClient _supabase;
  Timer? _heartbeat;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _playbackSub;
  bool _enabled = true; // privacy gate

  String? _userId;
  BloomeeMusicPlayer? _player;

  Future<void> start() async {
    _userId = _supabase.auth.currentUser?.id;
    if (_userId == null) return;
    _player = await PlayerInitializer().getBloomeeMusicPlayer();

    // Listen for media item changes
    _mediaItemSub = _player!.mediaItem.listen((item) {
      if (!_enabled) return;
      _upsertNowPlaying(isHeartbeat: false);
    });

    // Listen for play/pause
    _playbackSub = _player!.playbackState.listen((state) {
      if (!_enabled) return;
      _upsertNowPlaying(isHeartbeat: false);
    });

    // Heartbeat every 12 seconds
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_enabled) return;
      _upsertNowPlaying(isHeartbeat: true);
    });
  }

  Future<void> stop() async {
    await _mediaItemSub?.cancel();
    await _playbackSub?.cancel();
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      // Optional: clear status by setting is_playing=false
      _upsertNowPlaying(forceStop: true);
    }
  }

  Future<void> _upsertNowPlaying({bool isHeartbeat = false, bool forceStop = false}) async {
    if (_userId == null || _player == null) return;
    final media = _player!.currentMedia;
    final isPlaying = forceStop ? false : _player!.audioPlayer.playing;

    // If no media and not playing, just stop status
    if ((media.id.isEmpty || media.title.isEmpty) && !isPlaying) {
      await _supabase.from('now_playing').upsert({
        'user_id': _userId,
        'is_playing': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      return;
    }

    final payload = {
      'user_id': _userId,
      'track_id': media.id,
      'title': media.title,
      'artist': media.artist,
      'artwork_url': media.artUri.toString(),
      'progress_ms': _player!.audioPlayer.position.inMilliseconds,
      'is_playing': isPlaying,
      'extras': media.extras ?? {},
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _supabase.from('now_playing').upsert(payload, onConflict: 'user_id');
    } catch (_) {
      // Swallow errors to avoid affecting playback
    }
  }
}
