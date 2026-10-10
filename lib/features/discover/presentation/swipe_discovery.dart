import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/formatters.dart';
import '../../accounts/consumer_controller.dart';
import '../../bookings/presentation/viewing_request_screen.dart';
import '../../compare/compare_controller.dart';
import '../../compare/presentation/compare_screen.dart';
import '../../favorites/favorites_controller.dart';
import '../../listings/domain/property.dart';
import '../../listings/presentation/media_gallery.dart';
import '../../listings/presentation/property_detail_screen.dart';

class SwipePosition {
  int property = 0;
  final media = <String, int>{};
}

class SwipeDiscovery extends StatefulWidget {
  const SwipeDiscovery(
      {super.key,
      required this.items,
      required this.active,
      required this.hasMore,
      required this.loadingMore,
      required this.onMore,
      required this.position});
  final List<Property> items;
  final SwipePosition position;
  final bool active, hasMore, loadingMore;
  final Future<void> Function() onMore;
  @override
  State<SwipeDiscovery> createState() => _SwipeDiscoveryState();
}

class _SwipeDiscoveryState extends State<SwipeDiscovery> {
  late final page = PageController(
      initialPage: widget.position.property.clamp(0, widget.items.length - 1));
  late int index = widget.position.property.clamp(0, widget.items.length - 1);
  bool routeActive = true;
  Map<String, int> get mediaPositions => widget.position.media;
  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  Future<void> open(Widget screen) async {
    setState(() => routeActive = false);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => routeActive = true);
  }

  void step(int delta) {
    final next = (index + delta).clamp(0, widget.items.length - 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      page.jumpToPage(next);
    } else {
      page.animateToPage(next,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
      controller: page,
      scrollDirection: Axis.vertical,
      itemCount: widget.items.length,
      onPageChanged: (value) {
        setState(() => index = value);
        widget.position.property = value;
        final account = context.read<ConsumerController>();
        account.recordRecent(widget.items[value].id);
        if (value >= widget.items.length - 2 &&
            widget.hasMore &&
            !widget.loadingMore) widget.onMore();
      },
      itemBuilder: (context, i) {
        final property = widget.items[i];
        final active = widget.active && routeActive && i == index;
        final media = property.media.isNotEmpty
            ? property.media
            : property.cover != null
                ? [property.cover!]
                : <PropertyMedia>[];
        return Semantics(
            label: 'Home ${i + 1} of ${widget.items.length}',
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final information = _information(context, property, i, wide);
              final stage = ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ColoredBox(
                      color: const Color(0xff172720),
                      child: active
                          ? MediaGallery(
                              key: ValueKey('${property.id}:active'),
                              media: media,
                              title: property.title,
                              initialIndex: (mediaPositions[property.id] ?? 0)
                                  .clamp(
                                      0, media.isEmpty ? 0 : media.length - 1),
                              fullscreen: true,
                              immersive: true,
                              active: active,
                              onIndexChanged: (value) =>
                                  mediaPositions[property.id] = value)
                          : property.imageUrl == null
                              ? const Center(
                                  child: Icon(Icons.home_work_outlined,
                                      color: Colors.white, size: 48))
                              : CachedNetworkImage(
                                  imageUrl: property.imageUrl!,
                                  memCacheWidth: 800,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                      child: Icon(Icons.photo_outlined,
                                          color: Colors.white)),
                                  errorWidget: (_, __, ___) => const Center(
                                      child: Text('More to discover in person',
                                          style: TextStyle(
                                              color: Colors.white))))));
              return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: wide
                      ? Row(children: [
                          Expanded(
                              flex: 3, child: SizedBox.expand(child: stage)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: information)
                        ])
                      : Column(children: [
                          Expanded(child: SizedBox.expand(child: stage)),
                          const SizedBox(height: 12),
                          information
                        ]));
            }));
      });
  Widget _information(
      BuildContext context, Property property, int i, bool wide) {
    final theme = Theme.of(context);
    final favorites = context.watch<FavoritesController>();
    final compare = context.watch<CompareController>();
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6);
    final copy = SizedBox(
        height: wide ? 300.0 : 90.0 * scale,
        child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatMoney(property.price),
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Text(property.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(property.location.shortLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
              [
                if ((property.bedrooms ?? 0) > 0) '${property.bedrooms} beds',
                if ((property.bathrooms ?? 0) > 0)
                  '${property.bathrooms} baths',
                if (property.size != null)
                  '${property.size!.round()} ${property.sizeUnit}',
                if (property.verified) 'Verified'
              ].join(' · '),
              style: theme.textTheme.labelSmall),
        ])));
    return Column(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) const Spacer(),
          copy,
          if (wide) const Spacer() else const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
                tooltip: favorites.contains(property.id)
                    ? 'Remove from Saved'
                    : 'Save property',
                isSelected: favorites.contains(property.id),
                selectedIcon: const Icon(Icons.favorite),
                icon: const Icon(Icons.favorite_outline),
                onPressed: () => favorites.toggle(property.id)),
            IconButton(
                tooltip: compare.contains(property.id)
                    ? 'Remove from compare'
                    : 'Add to compare',
                isSelected: compare.contains(property.id),
                icon: const Icon(Icons.balance_outlined),
                selectedIcon: const Icon(Icons.balance),
                onPressed: () async {
                  if (!await compare.toggle(property.id) && context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Compare up to two homes.')));
                }),
            IconButton(
                tooltip: 'Open comparison',
                onPressed: compare.ids.length == 2
                    ? () => open(const CompareScreen())
                    : null,
                icon: const Icon(Icons.compare_arrows)),
            Builder(
                builder: (context) => IconButton(
                    tooltip: 'Share property',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () async {
                      setState(() => routeActive = false);
                      final box = context.findRenderObject() as RenderBox?;
                      try {
                        await SharePlus.instance.share(ShareParams(
                            title: property.title,
                            text:
                                '${property.title}\nhttps://dnbhomes.com/properties/${property.slug}-${property.id}',
                            sharePositionOrigin: box == null
                                ? null
                                : box.localToGlobal(Offset.zero) & box.size));
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Sharing unavailable. Try again.')));
                      } finally {
                        if (mounted) setState(() => routeActive = true);
                      }
                    })),
          ]),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => open(PropertyDetailScreen(
                        idOrSlug: property.id, initial: property)),
                    child: const Text('View details'))),
            const SizedBox(width: 8),
            Expanded(
                child: FilledButton(
                    onPressed: () =>
                        open(ViewingRequestScreen(property: property)),
                    child: const Text('Request viewing')))
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
                tooltip: 'Previous property',
                onPressed: i == 0 ? null : () => step(-1),
                icon: const Icon(Icons.arrow_upward)),
            Text('${i + 1} / ${widget.items.length}',
                style: theme.textTheme.labelMedium),
            if (i == widget.items.length - 1 && widget.hasMore)
              TextButton(
                  onPressed: widget.loadingMore ? null : widget.onMore,
                  child: Text(widget.loadingMore ? 'Loading…' : 'More homes'))
            else
              IconButton(
                  tooltip: 'Next property',
                  onPressed:
                      i == widget.items.length - 1 ? null : () => step(1),
                  icon: const Icon(Icons.arrow_downward)),
          ]),
        ]);
  }
}
