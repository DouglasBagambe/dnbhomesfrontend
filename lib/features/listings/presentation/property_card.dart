import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../compare/compare_controller.dart';
import '../../favorites/favorites_controller.dart';
import '../domain/property.dart';

enum PropertyCardLayout { vertical, horizontal, compact }

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    this.layout = PropertyCardLayout.vertical,
    this.showCompare = true,
  });
  final Property property;
  final VoidCallback onTap;
  final PropertyCardLayout layout;
  final bool showCompare;
  @override
  Widget build(BuildContext context) {
    final compact = layout == PropertyCardLayout.compact;
    final horizontal = layout == PropertyCardLayout.horizontal;
    final image = compact
        ? _image(context, 108, 154)
        : LayoutBuilder(
            builder: (context, constraints) => _image(
                context, constraints.maxWidth, constraints.maxWidth * .75));
    final details = _details(context);
    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: compact
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  image,
                  Expanded(child: details),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [image, details],
              ),
      ),
    );
    return Semantics(
      button: true,
      label:
          '${property.title}, ${formatMoney(property.price)}, ${property.location.shortLabel}',
      child: SizedBox(width: horizontal ? 272 : null, child: card),
    );
  }

  Widget _image(BuildContext context, double width, double height) => Stack(
        children: [
          SizedBox(
            width: width,
            height: height,
            child: Semantics(
              image: true,
              excludeSemantics: true,
              label: property.cover?.alt ??
                  (property.media.isNotEmpty
                      ? property.media.first.alt
                      : null) ??
                  property.title,
              child: property.imageUrl == null
                  ? _placeholder(context)
                  : CachedNetworkImage(
                      imageUrl: property.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 800,
                      placeholder: (_, __) => _placeholder(context),
                      errorWidget: (_, __, ___) => _placeholder(context),
                    ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Consumer<FavoritesController>(
              builder: (_, favorites, __) => _roundButton(
                context,
                favorites.contains(property.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
                'Favorite',
                () => favorites.toggle(property.id),
                selected: favorites.contains(property.id),
              ),
            ),
          ),
          Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.deep.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                      switch (property.purpose) {
                        'sale' => 'For sale',
                        'short_stay' => 'Short stay',
                        _ => 'For rent'
                      },
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)))),
        ],
      );
  Widget _placeholder(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.home_work_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
  Widget _details(BuildContext context) {
    final facts = [
      if ((property.bedrooms ?? 0) > 0) '${property.bedrooms} beds',
      if ((property.bathrooms ?? 0) > 0) '${property.bathrooms} baths',
      if (property.size != null)
        '${property.size!.round()} ${property.sizeUnit}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _textSlot(
                  context,
                  formatMoney(property.price),
                  lines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _textSlot(
            context,
            property.title,
            lines: 2,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 17,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  property.location.shortLabel.isEmpty
                      ? property.location.address
                      : property.location.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(12) * 1.35,
            child: property.verified
                ? Row(children: [
                    Icon(Icons.verified_outlined,
                        size: 15, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    const Text('Verified',
                        style: TextStyle(fontSize: 12, height: 1.35)),
                  ])
                : null,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _textSlot(
                  context,
                  facts.join(' · '),
                  lines: 1,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (showCompare)
                Consumer<CompareController>(
                  builder: (_, compare, __) => IconButton(
                    tooltip: compare.contains(property.id)
                        ? 'Remove from compare'
                        : 'Add to compare',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () async {
                      final added = await compare.toggle(property.id);
                      if (!added && context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Compare is limited to two properties.',
                            ),
                          ),
                        );
                    },
                    icon: Icon(
                      compare.contains(property.id)
                          ? Icons.balance
                          : Icons.balance_outlined,
                      size: 19,
                      color: compare.contains(property.id)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textSlot(BuildContext context, String text,
      {required int lines, TextStyle? style}) {
    final resolved =
        (style ?? DefaultTextStyle.of(context).style).copyWith(height: 1.3);
    return SizedBox(
        height:
            MediaQuery.textScalerOf(context).scale(resolved.fontSize ?? 14) *
                1.3 *
                lines,
        child: Text(text,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: resolved,
            strutStyle:
                StrutStyle.fromTextStyle(resolved, forceStrutHeight: true)));
  }

  Widget _roundButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool selected = false,
  }) =>
      Semantics(
        button: true,
        toggled: selected,
        label: label,
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(
              icon,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            iconSize: 21,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
        ),
      );
}
