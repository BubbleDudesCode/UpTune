// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:developer';
import 'package:Bloomee/model/MediaPlaylistModel.dart';
import 'package:Bloomee/model/album_onl_model.dart';
import 'package:Bloomee/model/artist_onl_model.dart';
import 'package:Bloomee/model/playlist_onl_model.dart';
import 'package:equatable/equatable.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';
import 'package:Bloomee/services/cloud_sync/supabase_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:Bloomee/services/db/cubit/bloomee_db_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'library_items_state.dart';

class LibraryItemsCubit extends Cubit<LibraryItemsState> {
  StreamSubscription? playlistWatcherDB;
  StreamSubscription? savedCollecsWatcherDB;
  RealtimeChannel? _likesChannel;
  RealtimeChannel? _plItemsChannel;
  final BloomeeDBCubit bloomeeDBCubit;

  LibraryItemsCubit({
    required this.bloomeeDBCubit,
  }) : super(LibraryItemsLoading()) {
    // Start with a loading state
    _initialize();
  }

  void _initRealtime() {
    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;
    if (user == null) return;

    // Likes changes
    _likesChannel = supa.channel('rl_likes_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'likes',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: user.id),
        callback: (payload) async {
          await refreshFromCloud();
          SnackbarService.showMessage("Synced from cloud");
        },
      )
      ..subscribe();

    // Playlist items changes
    _plItemsChannel = supa.channel('rl_playlist_items_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'playlist_items',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: user.id),
        callback: (payload) async {
          await refreshFromCloud();
          SnackbarService.showMessage("Synced from cloud");
        },
      )
      ..subscribe();
  }

  Future<void> syncFromCloud() async {
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      final svc = SupabaseSyncService.instance;

      // 1) Sync Likes from Supabase to local DB
      // Clear local liked songs first to prevent duplicates
      final likes = await svc.fetchLikes();
      
      // Get cloud song IDs
      final Set<String> cloudLikedIds = likes.map((l) => (l['song_id'] ?? '') as String).where((id) => id.isNotEmpty).toSet();
      
      // Get local liked songs
      final existingLiked = await BloomeeDBService.getPlaylistItemsByName(BloomeeDBService.likedPlaylist) ?? [];
      
      // Remove songs from local DB that are NOT in cloud (unliked on other device)
      for (final localItem in existingLiked) {
        if (!cloudLikedIds.contains(localItem.permaURL)) {
          await BloomeeDBService.removeMediaItemFromPlaylist(
            localItem,
            MediaPlaylistDB(playlistName: BloomeeDBService.likedPlaylist)
          );
        }
      }
      
      // Add new likes from cloud
      final Set<String> localLikedIds = existingLiked.map((e) => e.permaURL).toSet();
      
      if (likes.isNotEmpty) {
        await BloomeeDBService.addPlaylist(MediaPlaylistDB(playlistName: BloomeeDBService.likedPlaylist));
        
        // Reverse the list so oldest are inserted first, newest last (to appear at top)
        final reversedLikes = likes.reversed.toList();
        
        for (final l in reversedLikes) {
          final songId = (l['song_id'] ?? '') as String;
          if (songId.isEmpty || localLikedIds.contains(songId)) continue;
          
          final item = MediaItemDB(
            title: (l['title'] ?? 'Unknown') as String,
            album: '',
            artist: (l['artist'] ?? 'Unknown') as String,
            artURL: (l['image_url'] ?? '') as String,
            genre: 'Unknown',
            mediaID: songId,
            streamingURL: '',
            source: (l['provider'] ?? 'cloud') as String,
            duration: null,
            permaURL: songId,
            language: 'Unknown',
            isLiked: true,
          );
          await BloomeeDBService.addMediaItem(item, BloomeeDBService.likedPlaylist);
        }
      }

      // 2) Sync Playlists
      final playlists = await svc.fetchPlaylists();
      for (final p in playlists) {
        final name = (p['name'] ?? '').toString();
        if (name.isEmpty) continue;
        if (BloomeeDBService.standardPlaylists.contains(name)) continue; // Liked handled above

        // Fetch playlist items from cloud
        // Local DB will be updated through normal user actions (add/remove from playlist)
        final items = await svc.fetchPlaylistItems((p['id'] ?? '') as String);
      }
    } catch (e) {
      // ignore sync errors to avoid blocking local UI
      log('Cloud sync failed: $e', name: 'LibraryItemsCubit');
    }
  }

  @override
  Future<void> close() {
    playlistWatcherDB?.cancel();
    savedCollecsWatcherDB?.cancel();
    try {
      _likesChannel?.unsubscribe();
      _plItemsChannel?.unsubscribe();
    } catch (_) {}
    return super.close();
  }

  Future<void> _initialize() async {
    // Initial fetch
    await syncFromCloud();
    await Future.wait([
      getAndEmitPlaylists(),
      getAndEmitSavedOnlCollections(),
    ]);

    // Setup watchers for subsequent updates
    _getDBWatchers();

    // Setup realtime listeners for cross-device sync
    _initRealtime();
  }

  Future<void> refreshFromCloud() async {
    await syncFromCloud();
    await getAndEmitPlaylists();
    await getAndEmitSavedOnlCollections();
  }

  Future<void> _getDBWatchers() async {
    playlistWatcherDB =
        (await BloomeeDBService.getPlaylistsWatcher()).listen((_) {
      getAndEmitPlaylists();
    });
    savedCollecsWatcherDB =
        (await BloomeeDBService.getSavedCollecsWatcher()).listen((_) {
      getAndEmitSavedOnlCollections();
    });
  }

  Future<void> getAndEmitPlaylists() async {
    try {
      final mediaPlaylists = await BloomeeDBService.getPlaylists4Library();
      final playlistItems = mediaPlaylistsDB2ItemProperties(mediaPlaylists);

      // When emitting, copy existing parts of the state to avoid losing data
      emit(state.copyWith(playlists: playlistItems));
    } catch (e) {
      log("Error fetching playlists: $e", name: "LibraryItemsCubit");
      emit(const LibraryItemsError("Failed to load your playlists."));
    }
  }

  Future<void> getAndEmitSavedOnlCollections() async {
    try {
      final collections = await BloomeeDBService.getSavedCollections();
      final artists = collections.whereType<ArtistModel>().toList();
      final albums = collections.whereType<AlbumModel>().toList();
      final onlinePlaylists =
          collections.whereType<PlaylistOnlModel>().toList();

      emit(state.copyWith(
        artists: artists,
        albums: albums,
        playlistsOnl: onlinePlaylists,
      ));
    } catch (e) {
      log("Error fetching saved collections: $e", name: "LibraryItemsCubit");
      emit(const LibraryItemsError("Failed to load your saved items."));
    }
  }

  List<PlaylistItemProperties> mediaPlaylistsDB2ItemProperties(
      List<MediaPlaylist> mediaPlaylists) {
    return mediaPlaylists
        .map((element) => PlaylistItemProperties(
              playlistName: element.playlistName,
              subTitle: "${element.mediaItems.length} Items",
              coverImgUrl: element.imgUrl ??
                  (element.mediaItems.isNotEmpty
                      ? element.mediaItems.first.artUri?.toString()
                      : null),
            ))
        .toList();
  }

  void removePlaylist(MediaPlaylistDB mediaPlaylistDB) {
    if (mediaPlaylistDB.playlistName == BloomeeDBService.likedPlaylist) {
      SnackbarService.showMessage("'${BloomeeDBService.likedPlaylist}' playlist cannot be deleted");
      return;
    }
    if (mediaPlaylistDB.playlistName != "Null") {
      BloomeeDBService.removePlaylist(mediaPlaylistDB);
      // The watcher will automatically trigger a state update.
      SnackbarService.showMessage(
          "Playlist ${mediaPlaylistDB.playlistName} removed");
    }
  }

  Future<void> addToPlaylist(
      MediaItemModel mediaItem, MediaPlaylistDB mediaPlaylistDB) async {
    if (mediaPlaylistDB.playlistName != "Null") {
      await bloomeeDBCubit.addMediaItemToPlaylist(mediaItem, mediaPlaylistDB);
      // The watcher will automatically trigger a state update.
    }
  }

  void removeFromPlaylist(
      MediaItemModel mediaItem, MediaPlaylistDB mediaPlaylistDB) {
    if (mediaPlaylistDB.playlistName != "Null") {
      bloomeeDBCubit.removeMediaFromPlaylist(mediaItem, mediaPlaylistDB);
      // The watcher will automatically trigger a state update.
      SnackbarService.showMessage(
          "Removed ${mediaItem.title} from ${mediaPlaylistDB.playlistName}");
    }
  }

  Future<List<MediaItemModel>?> getPlaylist(String playlistName) async {
    try {
      final playlist =
          await BloomeeDBService.getPlaylistItemsByName(playlistName);

      return playlist?.map((e) => MediaItemDB2MediaItem(e)).toList();
    } catch (e) {
      log("Error in getting playlist: $e", name: "libItemCubit");
      return null;
    }
  }
}
