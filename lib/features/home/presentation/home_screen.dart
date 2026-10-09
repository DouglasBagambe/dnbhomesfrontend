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
import '../../settings/presentation/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  ApiFailure? failure;
  List<Property> featured = [], recommended = [], latest = [];
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
    } on ApiFailure catch (error) {
      if (mounted)
        setState(() {
          failure = error;
          loading = false;
        });
    }
  }

  void open(Property item) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PropertyDetailScreen(
              idOrSlug: item.slug.isEmpty ? item.id : item.slug,
              initial: item)));
  @override
  Widget build(BuildContext context) => SafeArea(
      child: RefreshIndicator(
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
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.tune))
      ]));
  List<Widget> _content() {
    final hero = featured.isNotEmpty ? featured : latest;
    final locations = <String, int>{};
    for (final item in latest) {
      final label = item.location.area.isNotEmpty
          ? item.location.area
          : item.location.district;
      if (label.isNotEmpty) locations[label] = (locations[label] ?? 0) + 1;
    }
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
      if (featured.isNotEmpty) _section('Featured homes', featured),
      if (recommended.isNotEmpty)
        _section('Popular right now', recommended,
            subtitle: 'Verified listings to explore'),
      if (locations.isNotEmpty)
        SliverToBoxAdapter(
            child: _Locations(
                items: locations.keys.take(6).toList(),
                onTap: (area) => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DiscoverScreen(
                            initialQuery: ListingQuery(area: area)))))),
      if (latest.isNotEmpty) _section('Fresh on Homes', latest),
      const SliverPadding(padding: EdgeInsets.only(bottom: 110))
    ];
  }

  Widget _section(String title, List<Property> items, {String? subtitle}) =>
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
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const DiscoverScreen())),
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
                            Text('Find your place\nin Uganda.',
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
                                                Text(
                                                    'Find your place\nin Uganda.',
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
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Browse by type',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map((item) => TextButton.icon(
                        onPressed: () => onSelect(item.$3),
                        icon: Icon(item.$2, size: 20),
                        label: Text(item.$1),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                      ))
                  .toList()),
        ]));
  }
}

class _Locations extends StatelessWidget {
  const _Locations({required this.items, required this.onTap});
  final List<String> items;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Explore locations',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ...items.map((item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(item),
            trailing: const Icon(Icons.arrow_forward, size: 20),
            onTap: () => onTap(item))),
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
