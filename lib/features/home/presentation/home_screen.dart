import '../../../core/widgets/brand_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/states.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/domain/property.dart';
import '../../listings/presentation/property_carousel.dart';
import '../../listings/presentation/property_detail_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../tours/tours_screen.dart';
import '../../accounts/consumer_controller.dart';
import '../../accounts/recent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.active = true});
  final bool active;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  ApiFailure? failure;
  List<Property> featured = [], recommended = [], latest = [], recent = [];
  int recentEpoch = 0;
  List<String> recentIds = [];
  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) loadRecent();
  }

  Future<void> loadRecent() async {
    final epoch = ++recentEpoch;
    final account = context.read<ConsumerController>();
    final repo = context.read<ListingsRepository>();
    final prefs = await SharedPreferences.getInstance();
    final ids = account.signedIn
        ? account.recent
        : prefs.getStringList('homes_guest_recent') ?? <String>[];
    final values = await Future.wait(ids.take(6).map((id) async {
      try {
        return await repo.get(id);
      } catch (_) {
        return null;
      }
    }));
    if (mounted && epoch == recentEpoch)
      setState(() {
        recentIds = List.of(ids);
        recent = values.whereType<Property>().toList();
      });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load({bool refresh = false}) async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final repo = context.read<ListingsRepository>();
      final results = await Future.wait([
        repo.list(const ListingQuery(featured: true, limit: 8),
            refresh: refresh),
        repo.list(
            const ListingQuery(
                verified: true, limit: 8, sort: ListingSort.popular),
            refresh: refresh),
        repo.list(const ListingQuery(limit: 10), refresh: refresh)
      ]);
      if (!mounted) return;
      setState(() {
        featured = results[0].items;
        recommended = results[1].items;
        latest = results[2].items;
        loading = false;
      });
      await loadRecent();
    } on ApiFailure catch (error) {
      if (mounted)
        setState(() {
          failure = error;
          loading = false;
        });
    }
  }

  void open(Property item) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(
                idOrSlug: item.slug.isEmpty ? item.id : item.slug,
                initial: item)));
    if (mounted) loadRecent();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: BrandRefreshIndicator(
          onRefresh: () => load(refresh: true),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _topBar()),
            if (loading)
              const SliverToBoxAdapter(child: _LoadingHome())
            else if (failure != null)
              SliverToBoxAdapter(
                  child: SizedBox(
                      height: 280,
                      child: AppErrorState(
                          message: failure!.message, onRetry: load)))
            else
              ..._content()
          ])));
  Widget _topBar() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Row(children: [
        Semantics(
            label: 'Homes',
            child: Row(children: [
              SvgPicture.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/dnblogdark-removebg-preview.svg'
                    : 'assets/images/dnblogolight-removebg-preview.svg',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 12),
              Container(
                  width: 1, height: 20, color: Theme.of(context).dividerColor),
              const SizedBox(width: 12),
              const Text('HOMES',
                  style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700)),
            ])),
        const Spacer(),
        IconButton(
            tooltip: 'Open Reels',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ToursScreen())),
            icon: const Icon(Icons.video_library_outlined))
      ]));
  List<Widget> _content() {
    final hero = featured.isNotEmpty ? featured : latest;
    final locations = <String, Property>{};
    for (final item in [...latest, ...recommended, ...featured]) {
      final key = '${item.location.area}|${item.location.district}';
      if (item.location.shortLabel.isNotEmpty)
        locations.putIfAbsent(key, () => item);
    }
    final shown = featured.map((p) => p.id).toSet();
    final popular = recommended.where((p) => !shown.contains(p.id)).toList();
    shown.addAll(popular.map((p) => p.id));
    final fresh = latest.where((p) => !shown.contains(p.id)).toList();
    return [
      SliverToBoxAdapter(
          child: _Hero(items: hero.take(5).toList(), onTap: open)),
      SliverToBoxAdapter(
          child: _SearchEntry(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchScreen())))),
      SliverToBoxAdapter(
          child: _Browse(
              onSelect: (query) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DiscoverScreen(initialQuery: query))))),
      if (featured.isNotEmpty)
        _section('Featured homes', featured,
            query: const ListingQuery(featured: true)),
      if (popular.isNotEmpty)
        _section('Popular right now', popular,
            subtitle: 'Verified listings to explore',
            query:
                const ListingQuery(verified: true, sort: ListingSort.popular)),
      if (locations.isNotEmpty)
        SliverToBoxAdapter(
            child: _Locations(
                items: locations.values.take(8).toList(),
                onTap: (place) => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DiscoverScreen(
                            initialQuery: ListingQuery(
                                area: place.location.area.isEmpty
                                    ? null
                                    : place.location.area,
                                district: place.location.district.isEmpty
                                    ? null
                                    : place.location.district)))))),
      if (recent.isNotEmpty)
        _section('Recently viewed', recent,
            onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecentHomesScreen(ids: recentIds)))),
      if (fresh.isNotEmpty)
        _section('Fresh on Homes', fresh,
            query: const ListingQuery(sort: ListingSort.newest)),
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 8),
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.video_library_outlined),
                            const SizedBox(height: 12),
                            Text('Watch property videos',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text(
                                'Walk through properties on video, then explore the details at your own pace.'),
                            const SizedBox(height: 12),
                            TextButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ToursScreen())),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Explore Reels'))
                          ]))))),
      const SliverPadding(padding: EdgeInsets.only(bottom: 110))
    ];
  }

  Widget _section(String title, List<Property> items,
          {String? subtitle,
          ListingQuery query = const ListingQuery(),
          VoidCallback? onSeeAll}) =>
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    if (subtitle != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(subtitle,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant)))
                                  ])),
                              TextButton(
                                  onPressed: onSeeAll ??
                                      () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => DiscoverScreen(
                                                  initialQuery: query))),
                                  child: const Text('See all'))
                            ])),
                    const SizedBox(height: 12),
                    items.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.home_work_outlined,
                            title: 'No listings yet',
                            message: 'New properties will appear here.')
                        : PropertyCarousel(
                            items: items,
                            onTap: open,
                            padding: const EdgeInsets.symmetric(horizontal: 20))
                  ])));
}

class _Hero extends StatefulWidget {
  const _Hero({required this.items, required this.onTap});
  final List<Property> items;
  final ValueChanged<Property> onTap;
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  int page = 0;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: SizedBox(
              height:
                  340 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
              child: widget.items.isEmpty
                  ? Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.home_work_outlined, size: 36),
                            const SizedBox(height: 24),
                            Text("Let's find you\na home.",
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    Theme.of(context).textTheme.displaySmall),
                            const SizedBox(height: 16),
                            const Text(
                                'No published homes yet. Explore property types or check back for new listings.'),
                          ]),
                    )
                  : Stack(fit: StackFit.expand, children: [
                      PageView.builder(
                          onPageChanged: (value) =>
                              setState(() => page = value),
                          itemCount: widget.items.length,
                          itemBuilder: (_, index) {
                            final item = widget.items[index];
                            return Semantics(
                                label: 'Open ${item.title}',
                                button: true,
                                child: InkWell(
                                    onTap: () => widget.onTap(item),
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      if (item.imageUrl != null)
                                        CachedNetworkImage(
                                            imageUrl: item.imageUrl!,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 1200,
                                            errorWidget: (_, __, ___) =>
                                                const ColoredBox(
                                                    color: AppColors.deep))
                                      else
                                        const ColoredBox(color: AppColors.deep),
                                      const DecoratedBox(
                                          decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                            Color(0x66123D32),
                                            Color(0xDD0B2A22)
                                          ]))),
                                      Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                    'PROPERTY DISCOVERY IN UGANDA',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        letterSpacing: 1.2,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                const SizedBox(height: 16),
                                                Text("Let's find you\na home.",
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .displaySmall
                                                        ?.copyWith(
                                                            color:
                                                                Colors.white)),
                                                const Spacer(),
                                                Text(item.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                const SizedBox(height: 24),
                                              ])),
                                    ])));
                          }),
                      Positioned(
                          right: 24,
                          bottom: 16,
                          child: Text('${page + 1} / ${widget.items.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12))),
                    ]),
            )),
      );
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Icon(Icons.search,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Area, neighbourhood or property',
                          style: Theme.of(context).textTheme.bodyMedium)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ]))),
      ));
}

class _Browse extends StatelessWidget {
  const _Browse({required this.onSelect});
  final ValueChanged<ListingQuery> onSelect;
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Rent', Icons.key_outlined, const ListingQuery(purpose: 'rent')),
      ('Buy', Icons.sell_outlined, const ListingQuery(purpose: 'sale')),
      (
        'Short Stay',
        Icons.bed_outlined,
        const ListingQuery(purpose: 'short_stay')
      ),
      ('Land', Icons.landscape_outlined, const ListingQuery(type: 'land')),
      (
        'Commercial',
        Icons.storefront_outlined,
        const ListingQuery(type: 'commercial')
      ),
    ];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontFamily: 'Roboto',
      letterSpacing: 0,
      color: colors.onSurface,
    );
    // Keep the five destinations on one rail, with room to scroll on compact
    // screens or when larger accessibility text needs wider touch targets.
    final textPainter = TextPainter(
      text: TextSpan(text: 'Commercial', style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final minimumWidth = (textPainter.width + 4).clamp(64.0, double.infinity);
    textPainter.dispose();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Browse by type', style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - 40;
            final itemWidth = ((availableWidth - 16) / items.length)
                .clamp(minimumWidth, double.infinity);
            return SingleChildScrollView(
              key: const ValueKey('browse-type-rail'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) const SizedBox(width: 4),
                    SizedBox(
                      width: itemWidth,
                      child: Semantics(
                        button: true,
                        label: items[index].$1,
                        onTap: () => onSelect(items[index].$3),
                        child: ExcludeSemantics(
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => onSelect(items[index].$3),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: colors.primary
                                            .withValues(alpha: .06),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: colors.primary
                                              .withValues(alpha: .10),
                                        ),
                                      ),
                                      child: Icon(items[index].$2,
                                          size: 24, color: colors.primary),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(items[index].$1,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: labelStyle),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Locations extends StatelessWidget {
  const _Locations({required this.items, required this.onTap});
  final List<Property> items;
  final ValueChanged<Property> onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Find your neighbourhood',
                style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 6),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Explore the places you could call home.')),
        const SizedBox(height: 14),
        SizedBox(
            height:
                116 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.8),
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final place = items[i].location;
                  return SizedBox(
                      width: 184,
                      child: Card(
                          child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => onTap(items[i]),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 20),
                                          const Spacer(),
                                          Icon(Icons.north_east,
                                              size: 18,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)
                                        ]),
                                        const Spacer(),
                                        Text(
                                            place.area.isEmpty
                                                ? place.district
                                                : place.area,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        if (place.area.isNotEmpty &&
                                            place.district.isNotEmpty)
                                          Text(place.district,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                      ])))));
                })),
      ]));
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
            height: 340,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24))),
        const SizedBox(height: 24),
        const PropertySkeleton(),
      ]));
}
