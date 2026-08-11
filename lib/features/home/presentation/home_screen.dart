import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/states.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/domain/property.dart';
import '../../listings/presentation/property_card.dart';
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

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final repo = context.read<ListingsRepository>();
      final results = await Future.wait([
        repo.list(const ListingQuery(featured: true, limit: 8)),
        repo.list(const ListingQuery(
            verified: true, limit: 8, sort: ListingSort.popular)),
        repo.list(const ListingQuery(limit: 10))
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
          onRefresh: load,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _topBar()),
            if (loading)
              const SliverToBoxAdapter(child: _LoadingHome())
            else if (failure != null)
              SliverFillRemaining(
                  child:
                      AppErrorState(message: failure!.message, onRetry: load))
            else
              ..._content()
          ])));
  Widget _topBar() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Row(children: [
        Semantics(
            label: 'Homes',
            child: SvgPicture.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/dnblogdark-removebg-preview.svg'
                    : 'assets/images/dnblogolight-removebg-preview.svg',
                width: 58,
                height: 42)),
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
          child: _QuickFilters(
              onSelect: (query) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DiscoverScreen(initialQuery: query))))),
      SliverToBoxAdapter(
          child: _Browse(
              onSelect: (query) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DiscoverScreen(initialQuery: query))))),
      _section('Featured Properties', featured),
      _section('Recommended For You', recommended,
          subtitle: 'Popular, recently published verified listings'),
      SliverToBoxAdapter(
          child: _Locations(
              items: locations.keys.take(6).toList(),
              onTap: (area) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DiscoverScreen(
                          initialQuery: ListingQuery(area: area)))))),
      _section('Trending This Week', recommended),
      _section('Latest Listings', latest),
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
                    SizedBox(
                        height: 340,
                        child: items.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.home_work_outlined,
                                title: 'No listings yet',
                                message: 'New properties will appear here.')
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (_, i) => PropertyCard(
                                    property: items[i],
                                    onTap: () => open(items[i]),
                                    layout: PropertyCardLayout.horizontal),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 14),
                                itemCount: items.length))
                  ])));
}

class _Hero extends StatelessWidget {
  const _Hero({required this.items, required this.onTap});
  final List<Property> items;
  final ValueChanged<Property> onTap;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
        height: 270,
        child: PageView.builder(
            controller: PageController(viewportFraction: .9),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                      onTap: () => onTap(item),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Stack(fit: StackFit.expand, children: [
                            if (item.imageUrl != null)
                              Image.network(item.imageUrl!,
                                  fit: BoxFit.cover, cacheWidth: 1200)
                            else
                              ColoredBox(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest),
                            const DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                  Colors.transparent,
                                  Color(0xCC000000)
                                ]))),
                            Positioned(
                                left: 22,
                                right: 22,
                                bottom: 22,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          item.featured
                                              ? 'Featured home'
                                              : 'New to Homes',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              height: 1.15,
                                              fontWeight: FontWeight.w700))
                                    ]))
                          ]))));
            }));
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Semantics(
          button: true,
          label: 'Search properties, locations or agents',
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                  constraints: const BoxConstraints(minHeight: 66),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Row(children: [
                    Icon(Icons.search,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('Search properties, locations or agents...',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant))),
                    const Icon(Icons.arrow_forward)
                  ])))));
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.onSelect});
  final ValueChanged<ListingQuery> onSelect;
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Kampala', const ListingQuery(district: 'Kampala')),
      ('House', const ListingQuery(type: 'house')),
      ('Apartment', const ListingQuery(type: 'apartment')),
      ('Under 500k', const ListingQuery(maxPrice: 500000)),
      ('2 Bedrooms', const ListingQuery(bedrooms: 2))
    ];
    return SizedBox(
        height: 56,
        child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) => ActionChip(
                label: Text(items[i].$1),
                onPressed: () => onSelect(items[i].$2)),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: items.length));
  }
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
      )
    ];
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Browse by type',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          SizedBox(
              height: 102,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) => SizedBox(
                      width: 105,
                      child: OutlinedButton(
                          onPressed: () => onSelect(items[i].$3),
                          style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md))),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(items[i].$2),
                                const SizedBox(height: 8),
                                Text(items[i].$1, textAlign: TextAlign.center)
                              ]))),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: items.length))
        ]));
  }
}

class _Locations extends StatelessWidget {
  const _Locations({required this.items, required this.onTap});
  final List<String> items;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Popular Locations',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => ActionChip(
                    avatar: const Icon(Icons.location_on_outlined, size: 18),
                    label: Text(item),
                    onPressed: () => onTap(item)))
                .toList())
      ]));
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
            height: 250,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.xl))),
        const SizedBox(height: 20),
        ...List.generate(
            3,
            (_) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: PropertySkeleton()))
      ]));
}
