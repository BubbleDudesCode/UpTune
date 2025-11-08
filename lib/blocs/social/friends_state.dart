part of 'friends_cubit.dart';

class FriendsState extends Equatable {
  final bool loading;
  final bool searchLoading;
  final String query;
  final List<Map<String, dynamic>> friends;
  final List<Map<String, dynamic>> results;
  final String? error;
  final Set<String> requestedIds;
  final Map<String, Map<String, dynamic>> nowPlayingByUserId;

  const FriendsState({
    this.loading = false,
    this.searchLoading = false,
    this.query = '',
    this.friends = const [],
    this.results = const [],
    this.error,
    this.requestedIds = const <String>{},
    this.nowPlayingByUserId = const <String, Map<String, dynamic>>{},
  });

  FriendsState copyWith({
    bool? loading,
    bool? searchLoading,
    String? query,
    List<Map<String, dynamic>>? friends,
    List<Map<String, dynamic>>? results,
    String? error,
    Set<String>? requestedIds,
    Map<String, Map<String, dynamic>>? nowPlayingByUserId,
  }) {
    return FriendsState(
      loading: loading ?? this.loading,
      searchLoading: searchLoading ?? this.searchLoading,
      query: query ?? this.query,
      friends: friends ?? this.friends,
      results: results ?? this.results,
      error: error,
      requestedIds: requestedIds ?? this.requestedIds,
      nowPlayingByUserId: nowPlayingByUserId ?? this.nowPlayingByUserId,
    );
  }

  @override
  List<Object?> get props => [loading, searchLoading, query, friends, results, error, requestedIds, nowPlayingByUserId];
}
