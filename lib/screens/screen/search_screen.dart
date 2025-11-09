// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:developer';
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/model/source_engines.dart';
import 'package:Bloomee/screens/widgets/album_card.dart';
import 'package:Bloomee/screens/widgets/artist_card.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/playlist_card.dart';
import 'package:Bloomee/screens/widgets/sign_board_widget.dart';
import 'package:Bloomee/screens/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:Bloomee/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:Bloomee/blocs/search/fetch_search_results.dart';
import 'package:Bloomee/theme_data/default.dart';

class SearchScreen extends StatefulWidget {
  final String searchQuery;
  const SearchScreen({
    Key? key,
    this.searchQuery = "",
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late List<SourceEngine> availSourceEngines;
  late SourceEngine _sourceEngine;
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<ResultTypes> resultType =
      ValueNotifier(ResultTypes.songs);

  @override
  void dispose() {
    _scrollController.removeListener(loadMoreResults);
    _scrollController.dispose();
    _textEditingController.dispose();
    resultType.dispose();
    super.dispose();
  }

  void loadMoreResults() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _sourceEngine == SourceEngine.eng_JIS &&
        context.read<FetchSearchResultsCubit>().state.hasReachedMax == false) {
      context
          .read<FetchSearchResultsCubit>()
          .searchJISTracks(_textEditingController.text, loadMore: true);
    }
  }

  @override
  void initState() {
    super.initState();
    availSourceEngines = SourceEngine.values;
    _sourceEngine = availSourceEngines[0];

    // Rebuild when the query text changes so the title chip reflects current text
    _textEditingController.addListener(() {
      if (mounted) setState(() {});
    });

    setState(() {
      availableSourceEngines().then((value) {
        availSourceEngines = value;
        _sourceEngine = availSourceEngines[0];
      });
    });
    _scrollController.addListener(loadMoreResults);
    if (widget.searchQuery != "") {
      _textEditingController.text = widget.searchQuery;
      context.read<FetchSearchResultsCubit>().search(
            widget.searchQuery.toString(),
            sourceEngine: _sourceEngine,
            resultType: resultType.value,
          );
    }
  }

  Widget resultTypeChip(ResultTypes type) {
    final isSelected = resultType.value == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              resultType.value = type;
              context.read<FetchSearchResultsCubit>().checkAndRefreshSearch(
                    query: _textEditingController.text.toString(),
                    sE: _sourceEngine,
                    rT: type,
                  );
            });
          },
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: isSelected
                  ? Default_Theme.accentColor2
                  : Default_Theme.primaryColor2.withOpacity(0.03),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              side: BorderSide(
                  color: isSelected
                      ? Default_Theme.accentColor2
                      : Default_Theme.primaryColor1.withOpacity(0.1),
                  style: BorderStyle.solid,
                  width: 1.5)),
          child: Text(
            type.val,
            style: TextStyle(
                    color: isSelected
                        ? Default_Theme.primaryColor2
                        : Default_Theme.primaryColor1.withOpacity(0.7),
                    fontSize: 13.5,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500)
                .merge(Default_Theme.secondoryTextStyleMedium),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        onVerticalDragEnd: (DragEndDetails details) =>
            FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Default_Theme.themeColor,
            backgroundColor: Default_Theme.themeColor,
            title: const Text('Search'),
          ),
          backgroundColor: Default_Theme.themeColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textEditingController,
                              decoration: InputDecoration(
                                hintText: 'Find your next song obsession...',
                                isDense: true,
                                filled: true,
                                fillColor: Default_Theme.primaryColor2.withOpacity(0.06),
                                prefixIcon: const Icon(MingCute.search_2_fill, size: 20),
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
                                  borderSide: BorderSide(color: Default_Theme.accentColor2.withOpacity(0.7), width: 1.5),
                                ),
                              ),
                              onSubmitted: (value) {
                                context.read<FetchSearchResultsCubit>().search(
                                  value,
                                  sourceEngine: _sourceEngine,
                                  resultType: resultType.value,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              context.read<FetchSearchResultsCubit>().search(
                                _textEditingController.text,
                                sourceEngine: _sourceEngine,
                                resultType: resultType.value,
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Default_Theme.accentColor2,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder(
                        future: availableSourceEngines(),
                        builder: (context, snapshot) {
                          return snapshot.hasData || snapshot.data != null
                              ? Wrap(
                                direction: Axis.horizontal,
                                runSpacing: 8,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Container(
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Default_Theme.primaryColor2.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Default_Theme.primaryColor1.withOpacity(0.08),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: availSourceEngines.asMap().entries.map((entry) {
                                            final isSelected = _sourceEngine == entry.value;
                                            final isFirst = entry.key == 0;
                                            final isLast = entry.key == availSourceEngines.length - 1;
                                            
                                            return InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _sourceEngine = entry.value;
                                                });
                                                context
                                                    .read<FetchSearchResultsCubit>()
                                                    .checkAndRefreshSearch(
                                                      query: _textEditingController.text.toString(),
                                                      sE: entry.value,
                                                      rT: resultType.value,
                                                    );
                                              },
                                              borderRadius: BorderRadius.horizontal(
                                                left: isFirst ? const Radius.circular(24) : Radius.zero,
                                                right: isLast ? const Radius.circular(24) : Radius.zero,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Default_Theme.accentColor2
                                                      : Colors.transparent,
                                                  borderRadius: BorderRadius.horizontal(
                                                    left: isFirst ? const Radius.circular(22) : Radius.zero,
                                                    right: isLast ? const Radius.circular(22) : Radius.zero,
                                                  ),
                                                ),
                                                child: Text(
                                                  entry.value.value,
                                                  style: Default_Theme.secondoryTextStyleMedium.merge(
                                                    TextStyle(
                                                      color: isSelected
                                                          ? Default_Theme.primaryColor2
                                                          : Default_Theme.primaryColor1.withOpacity(0.6),
                                                      fontSize: 13.5,
                                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    for (var type in ResultTypes.values)
                                      resultTypeChip(type)
                                  ])
                              : const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: BlocBuilder<ConnectivityCubit, ConnectivityState>(
              builder: (context, state) {
                return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: state == ConnectivityState.disconnected
                        ? const SignBoardWidget(
                            icon: MingCute.wifi_off_line,
                            message: "No internet connection!",
                          )
                        : BlocConsumer<FetchSearchResultsCubit,
                            FetchSearchResultsState>(
                            builder: (context, state) {
                              if (state is FetchSearchResultsLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Default_Theme.accentColor2,
                                  ),
                                );
                              } else if (state.loadingState ==
                                  LoadingState.loaded) {
                                if (state.resultType == ResultTypes.songs &&
                                    state.mediaItems.isNotEmpty) {
                                  log("Search Results: ${state.mediaItems.length}",
                                      name: "SearchScreen");
                                  return ListView.builder(
                                    controller: _scrollController,
                                    itemCount: state.hasReachedMax
                                        ? state.mediaItems.length
                                        : state.mediaItems.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == state.mediaItems.length) {
                                        return const Center(
                                          child: SizedBox(
                                            height: 30,
                                            width: 30,
                                            child: CircularProgressIndicator(
                                              color: Default_Theme.accentColor2,
                                            ),
                                          ),
                                        );
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        child: SongCardWidget(
                                          song: state.mediaItems[index],
                                          onTap: () {
                                            context
                                                .read<BloomeePlayerCubit>()
                                                .bloomeePlayer
                                                .updateQueue(
                                              [state.mediaItems[index]],
                                              doPlay: true,
                                            );
                                          },
                                          onOptionsTap: () =>
                                              showMoreBottomSheet(context,
                                                  state.mediaItems[index]),
                                        ),
                                      );
                                    },
                                  );
                                } else if (state.resultType ==
                                        ResultTypes.albums &&
                                    state.albumItems.isNotEmpty) {
                                  return Align(
                                    alignment: Alignment.topCenter,
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        runSpacing: 10,
                                        children: [
                                          for (var album in state.albumItems)
                                            AlbumCard(album: album)
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (state.resultType ==
                                        ResultTypes.artists &&
                                    state.artistItems.isNotEmpty) {
                                  return Align(
                                    alignment: Alignment.topCenter,
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        runSpacing: 10,
                                        children: [
                                          for (var artist in state.artistItems)
                                            ArtistCard(artist: artist)
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (state.resultType ==
                                        ResultTypes.playlists &&
                                    state.playlistItems.isNotEmpty) {
                                  return Align(
                                    alignment: Alignment.topCenter,
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        runSpacing: 10,
                                        children: [
                                          for (var playlist
                                              in state.playlistItems)
                                            PlaylistCard(
                                              playlist: playlist,
                                              sourceEngine: _sourceEngine,
                                            )
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  return const SignBoardWidget(
                                      message:
                                          "No results found!\nTry another keyword or source engine!",
                                      icon: MingCute.sweats_line);
                                }
                              } else {
                                return const SignBoardWidget(
                                    message:
                                        "Search for your favorite songs\nand discover new ones!",
                                    icon: MingCute.search_2_line);
                              }
                            },
                            listener: (BuildContext context,
                                FetchSearchResultsState state) {
                              resultType.value = state.resultType;
                              if (state is! FetchSearchResultsLoaded &&
                                  state is! FetchSearchResultsInitial) {
                                _sourceEngine =
                                    state.sourceEngine ?? _sourceEngine;
                              }
                            },
                          ));
              },
            ),
          ),
        ),
      ),
    );
  }
}
