// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:flutter/material.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

enum LibItemTypes {
  userPlaylist,
  onlPlaylist,
  artist,
  album,
}

class LibItemCard extends StatefulWidget {
  final String title;
  final String coverArt;
  final String subtitle;
  final LibItemTypes type;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onLongPress;
  const LibItemCard({
    Key? key,
    required this.title,
    required this.coverArt,
    required this.subtitle,
    this.type = LibItemTypes.userPlaylist,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<LibItemCard> createState() => _LibItemCardState();
}

class _LibItemCardState extends State<LibItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: InkWell(
        splashColor: Default_Theme.primaryColor2.withOpacity(0.1),
        hoverColor: Colors.white.withOpacity(0.05),
        highlightColor: Default_Theme.primaryColor2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        onTap: widget.onTap ?? () {},
        onSecondaryTap: widget.onSecondaryTap ?? () {},
        onLongPress: widget.onLongPress ?? () {},
        child: SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              widget.type == LibItemTypes.userPlaylist
                  ? StreamBuilder<String>(
                      stream: context
                          .watch<BloomeePlayerCubit>()
                          .bloomeePlayer
                          .queueTitle,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data == widget.title) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              FontAwesome.chart_simple_solid,
                              color: Default_Theme.primaryColor2.withOpacity(1),
                              size: 15,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      })
                  : const SizedBox.shrink(),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: SizedBox.square(
                  dimension: 70,
                  child: widget.title == "Liked"
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF0844),
                                Color(0xFFFF6B6B),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF0844).withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Transform.rotate(
                                  angle: _rotationAnimation.value,
                                  child: const Icon(
                                    AntDesign.heart_fill,
                                    color: Colors.white,
                                    size: 35,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: switch (widget.type) {
                            LibItemTypes.userPlaylist => LoadImageCached(
                                imageUrl: formatImgURL(
                                    widget.coverArt.toString(), ImageQuality.medium)),
                            LibItemTypes.onlPlaylist => LoadImageCached(
                                imageUrl: formatImgURL(
                                    widget.coverArt.toString(), ImageQuality.medium)),
                            LibItemTypes.artist => ClipOval(
                                child: LoadImageCached(
                                    imageUrl: formatImgURL(
                                        widget.coverArt.toString(), ImageQuality.medium)),
                              ),
                            LibItemTypes.album => LoadImageCached(
                                imageUrl: formatImgURL(
                                    widget.coverArt.toString(), ImageQuality.medium)),
                          },
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: Default_Theme.secondoryTextStyle.merge(
                          const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: Default_Theme.primaryColor1)),
                    ),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      style: Default_Theme.secondoryTextStyle.merge(
                          const TextStyle(
                              fontSize: 14,
                              overflow: TextOverflow.fade,
                              fontWeight: FontWeight.w500,
                              color: Default_Theme.primaryColor1)),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
