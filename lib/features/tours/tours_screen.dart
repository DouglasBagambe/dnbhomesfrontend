import '../../core/widgets/brand_loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation_observer.dart';
import '../../core/utils/formatters.dart';
import '../favorites/favorites_controller.dart';
import '../listings/data/listings_repository.dart';
import '../listings/presentation/property_detail_screen.dart';
import 'tour_video.dart';
import 'tour_backdrop.dart';
import 'tours_feed.dart';

class ToursScreen extends StatefulWidget {
  const ToursScreen({super.key});
  @override
  State<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends State<ToursScreen> with RouteAware {
  late final ToursFeed feed;
  final pages = PageController();
  final mediaPositions = <String, int>{};
  int index = 0;
  bool muted = true, covered = false;
  @override
  void initState() {
    super.initState();
    feed = ToursFeed(context.read<ListingsRepository>())..addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) feed.more();
    });
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) homesRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    if (mounted) setState(() => covered = true);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => covered = false);
  }

  @override
  void didPop() {
    if (mounted) setState(() => covered = true);
  }

  @override
  void dispose() {
    homesRouteObserver.unsubscribe(this);
    feed.removeListener(changed);
    feed.dispose();
    pages.dispose();
    super.dispose();
  }

  Future<void> location() async {
    setState(() => covered = true);
    final appTheme = Theme.of(context);
    final selected = await showModalBottomSheet<TourLocation>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: appTheme.colorScheme.surface,
        builder: (_) => Theme(
            data: appTheme,
            child: DefaultTextStyle(
                style: appTheme.textTheme.bodyMedium ??
                    TextStyle(color: appTheme.colorScheme.onSurface),
                child: _LocationPicker(
                    locations: feed.locations.values.toList(),
                    selected: feed.location))));
    if (!mounted) return;
    setState(() => covered = false);
    if (selected == null) return;
    if (pages.hasClients) pages.jumpToPage(0);
    index = 0;
    mediaPositions.clear();
    await feed.select(selected.key == '|' ? null : selected);
  }

  Future<void> share(TourClip clip) async {
    setState(() => covered = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
          text:
              '${clip.property.title}\n${AppConfig.propertyUrl(clip.property.slug, clip.property.id)}',
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sharing is unavailable. Please try again.')));
    } finally {
      if (mounted) setState(() => covered = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light),
      child: Theme(
          data: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: Colors.black,
              colorScheme: const ColorScheme.dark(
                  primary: Colors.white, surface: Color(0xff111713))),
          child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(children: [
                const Positioned.fill(child: TourBackdrop()),
                Positioned.fill(
                    child: feed.clips.isEmpty
                        ? _empty()
                        : PageView.builder(
                            controller: pages,
                            scrollDirection: Axis.vertical,
                            itemCount: feed.clips.length + 1,
                            onPageChanged: (value) {
                              setState(() => index = value);
                              if (value >= feed.clips.length - 2 &&
                                  feed.hasMore &&
                                  !feed.busy &&
                                  feed.error == null) feed.more();
                            },
                            itemBuilder: (_, i) => i == feed.clips.length
                                ? _end()
                                : _property(feed.clips[i], i))),
                Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: DecoratedBox(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black87, Colors.transparent])),
                        child: SafeArea(
                            bottom: false,
                            child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 8, 12, 24),
                                child: Row(children: [
                                  IconButton(
                                      tooltip: 'Close Reels',
                                      onPressed: () =>
                                          Navigator.maybePop(context),
                                      icon: const Icon(Icons.arrow_back,
                                          color: Colors.white)),
                                  const Text('Reels',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: TextButton.icon(
                                          onPressed: location,
                                          icon: const Icon(
                                              Icons.location_on_outlined,
                                              size: 18),
                                          label: Text(
                                              feed.location?.label ??
                                                  'All locations',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: .10),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              shape: const StadiumBorder(
                                                  side: BorderSide(color: Colors.white24))))),
                                  IconButton(
                                      tooltip:
                                          muted ? 'Unmute reels' : 'Mute reels',
                                      onPressed: () =>
                                          setState(() => muted = !muted),
                                      icon: Icon(
                                          muted
                                              ? Icons.volume_off_outlined
                                              : Icons.volume_up_outlined,
                                          color: Colors.white)),
                                ]))))),
              ]))));
  Widget _empty() => SafeArea(
      child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 110, 28, 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (feed.busy)
                  const BrandLoading(color: Colors.white)
                else
                  const Icon(Icons.video_library_outlined,
                      color: Colors.white70, size: 46),
                const SizedBox(height: 20),
                Text(
                    feed.busy
                        ? 'Finding your next place…'
                        : feed.error != null
                            ? 'Reels couldn’t load'
                            : 'More places. A closer look.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(
                    feed.error ??
                        (feed.busy
                            ? 'Looking for property videos.'
                            : feed.location != null
                                ? 'No property videos found here yet. Try another location.'
                                : 'Property videos will appear here when listings include videos.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.5)),
                if (!feed.busy) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                      onPressed: feed.error != null || feed.hasMore
                          ? feed.more
                          : () => feed.select(feed.location),
                      icon: const Icon(Icons.refresh),
                      label: Text(feed.error != null
                          ? 'Retry reels'
                          : feed.hasMore
                              ? 'Continue searching'
                              : 'Refresh reels')),
                  if (feed.location != null)
                    TextButton(
                        onPressed: () => feed.select(null),
                        child: const Text('Explore all locations')),
                ],
              ]))));
  Widget _end() => SafeArea(
      child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (feed.busy)
                  const BrandLoading(color: Colors.white)
                else
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white70, size: 40),
                const SizedBox(height: 18),
                Text(
                    feed.busy
                        ? 'Loading more reels…'
                        : feed.error ??
                            (feed.hasMore
                                ? 'Keep exploring'
                                : 'You’re all caught up'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22)),
                const SizedBox(height: 14),
                if (!feed.busy && (feed.hasMore || feed.error != null))
                  OutlinedButton(
                      onPressed: feed.more,
                      child: const Text('Load more reels')),
                TextButton(
                    onPressed: location, child: const Text('Change location')),
                TextButton(
                    onPressed: () => pages.animateToPage(0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut),
                    child: const Text('Back to first tour')),
              ]))));
  Widget _property(TourClip clip, int i) {
    final property = clip.property;
    final selected = mediaPositions[clip.id] ?? 0;
    final short = MediaQuery.sizeOf(context).height < 500;
    return Stack(fit: StackFit.expand, children: [
      _TourMedia(
          key: ValueKey(clip.id),
          clip: clip,
          initialIndex: selected,
          active: index == i && !covered,
          muted: muted,
          onChanged: (media) =>
              setState(() => mediaPositions[clip.id] = media)),
      Positioned(
        bottom: MediaQuery.paddingOf(context).bottom + 42,
        left: 0,
        right: 0,
        child: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xc708100c)],
          )),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, short ? 12 : 28, 16, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                  child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height *
                        (short ? .26 : .36)),
                child: SingleChildScrollView(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (clip.media.length > 1) ...[
                      Row(children: [
                        Icon(
                            clip.media[selected].type == 'video'
                                ? Icons.videocam_outlined
                                : Icons.photo_outlined,
                            color: Colors.white70,
                            size: 15),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(
                                '${selected + 1} / ${clip.media.length}  ·  ${clip.media[selected].type == 'video' ? 'Video' : 'Photo'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12))),
                      ]),
                      const SizedBox(height: 10),
                    ],
                    Text(formatMoney(property.price),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5)),
                    const SizedBox(height: 7),
                    Text(property.title,
                        maxLines: short ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 5),
                    Text(property.location.shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    if (property.availabilityLabel != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(property.availabilityLabel!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PropertyDetailScreen(
                                    idOrSlug: property.id, initial: property))),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xfff7f4ee),
                            foregroundColor: const Color(0xff123d32),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        icon: const Icon(Icons.north_east, size: 17),
                        label: const Text('View property')),
                  ],
                )),
              )),
              const SizedBox(width: 16),
              Flex(
                  direction: short ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Consumer<FavoritesController>(
                        builder: (_, saved, __) => _TourAction(
                            compact: short,
                            tooltip: saved.contains(property.id)
                                ? 'Unsave property'
                                : 'Save property',
                            label:
                                saved.contains(property.id) ? 'Saved' : 'Save',
                            icon: saved.contains(property.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            selected: saved.contains(property.id),
                            onPressed: () async {
                              try {
                                await saved.toggle(property.id);
                              } catch (_) {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Couldn’t sync your saved home. Please try again.')));
                              }
                            })),
                    SizedBox(height: short ? 0 : 16, width: short ? 8 : 0),
                    _TourAction(
                        compact: short,
                        tooltip: 'Share property',
                        label: 'Share',
                        icon: Icons.ios_share_rounded,
                        onPressed: () => share(clip)),
                  ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({required this.locations, this.selected});
  final List<TourLocation> locations;
  final TourLocation? selected;
  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final locations = widget.locations
        .where((l) => l.label.toLowerCase().contains(search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
          child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            const Expanded(
                child: Text('Where would you like to explore?',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
            IconButton(
                tooltip: 'Close location picker',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 12),
          TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Find a neighbourhood or district'),
              onChanged: (v) => setState(() => search = v)),
          const SizedBox(height: 8),
          ListTile(
              leading: const Icon(Icons.public),
              title: const Text('All locations'),
              selected: widget.selected == null,
              onTap: () => Navigator.pop(context, const TourLocation('', ''))),
          for (final location in locations)
            ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(location.label),
                selected: widget.selected?.key == location.key,
                onTap: () => Navigator.pop(context, location)),
          if (locations.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No matching locations in the loaded inventory.')),
        ]),
      )),
    );
  }
}

class _TourMedia extends StatefulWidget {
  const _TourMedia(
      {super.key,
      required this.clip,
      required this.initialIndex,
      required this.active,
      required this.muted,
      required this.onChanged});
  final TourClip clip;
  final int initialIndex;
  final bool active, muted;
  final ValueChanged<int> onChanged;
  @override
  State<_TourMedia> createState() => _TourMediaState();
}

class _TourMediaState extends State<_TourMedia> {
  late final controller = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
      controller: controller,
      itemCount: widget.clip.media.length,
      onPageChanged: (value) {
        setState(() => index = value);
        widget.onChanged(value);
      },
      itemBuilder: (_, m) {
        final media = widget.clip.media[m];
        return media.type == 'video'
            ? TourVideo(
                key: ValueKey('${widget.clip.id}:${media.url}'),
                url: media.url,
                active: widget.active && index == m,
                muted: widget.muted,
                backdropUrl: widget.clip.property.imageUrl)
            : Stack(fit: StackFit.expand, children: [
                TourBackdrop(imageUrl: media.url),
                CachedNetworkImage(
                    imageUrl: media.url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: BrandLoading(color: Colors.white)),
                    errorWidget: (_, __, ___) => const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Photo unavailable · swipe for more',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70))))),
              ]);
      });
}

class _TourAction extends StatelessWidget {
  const _TourAction(
      {required this.tooltip,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.selected = false,
      this.compact = false});
  final String tooltip, label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected, compact;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .22),
                foregroundColor:
                    selected ? const Color(0xff9ce0bd) : Colors.white,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(48, 48)),
            icon: Icon(icon, size: 25)),
        if (!compact) const SizedBox(height: 4),
        if (!compact)
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
      ]);
}
