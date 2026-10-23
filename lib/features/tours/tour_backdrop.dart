import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A static property image softens unused space without a second video decoder.
/// The sharp, uncropped media remains the only interactive foreground layer.
class TourBackdrop extends StatelessWidget {
  const TourBackdrop({super.key, this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: IgnorePointer(
          child: ClipRect(
            child: Stack(fit: StackFit.expand, children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xff304b41),
                      Color(0xff101c18),
                      Color(0xff182e26)
                    ],
                  ),
                ),
              ),
              if (imageUrl?.isNotEmpty == true)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Transform.scale(
                    scale: 1.15,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      memCacheWidth: 480,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 220),
                      placeholder: (_, __) => const SizedBox.expand(),
                      errorWidget: (_, __, ___) => const SizedBox.expand(),
                    ),
                  ),
                ),
              const ColoredBox(color: Color(0x8a08120e)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .35, .65, 1],
                    colors: [
                      Color(0xb30a100d),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xe60a100d)
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}
