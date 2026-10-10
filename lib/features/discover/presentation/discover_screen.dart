import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/states.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/domain/property.dart';
import '../../listings/presentation/property_card.dart';
import '../../listings/presentation/property_detail_screen.dart';
import '../../search/presentation/search_screen.dart';
import 'filter_sheet.dart';
import 'swipe_discovery.dart';
import '../../compare/compare_controller.dart';
import '../../compare/presentation/compare_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen(
      {super.key,
      this.initialQuery = const ListingQuery(),
      this.active = true});
  final ListingQuery initialQuery;
  final bool active;
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late ListingQuery query = widget.initialQuery;
  final items = <Property>[];
  bool loading = true, loadingMore = false;
  ApiFailure? failure;
  int total = 0, pages = 0;
  int loadEpoch = 0;
  final scroll = ScrollController();
  bool swipe = false;
  SwipePosition swipePosition = SwipePosition();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
    scroll.addListener(() {
      if (scroll.position.extentAfter < 500 &&
          !loadingMore &&
          query.page < pages) more();
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    final epoch = ++loadEpoch;
    final requested = query.copyWith(page: 1);
    setState(() {
      loading = true;
      loadingMore = false;
      failure = null;
    });
    try {
      final page = await context.read<ListingsRepository>().list(
            requested,
            refresh: refresh,
          );
      if (!mounted || epoch != loadEpoch) return;
      setState(() {
        items
          ..clear()
          ..addAll(page.items);
        query = requested;
        swipePosition = SwipePosition();
        total = page.total;
        pages = page.pages;
        loading = false;
      });
    } on ApiFailure catch (error) {
      if (mounted && epoch == loadEpoch)
        setState(() {
          failure = error;
          loading = false;
        });
    }
  }

  Future<void> more() async {
    if (loading || loadingMore || query.page >= pages) return;
    final epoch = loadEpoch;
    setState(() => loadingMore = true);
    try {
      final next = query.copyWith(page: query.page + 1);
      final page = await context.read<ListingsRepository>().list(next);
      if (!mounted || epoch != loadEpoch) return;
      setState(() {
        items.addAll(page.items);
        query = next;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted && epoch == loadEpoch) setState(() => loadingMore = false);
    }
  }

  void purpose(String label) {
    query = switch (label) {
      'Buy' => query.copyWith(purpose: 'sale', clearType: true),
      'Rent' => query.copyWith(purpose: 'rent', clearType: true),
      'Short Stay' => query.copyWith(purpose: 'short_stay', clearType: true),
      'Land' => query.copyWith(type: 'land', clearPurpose: true),
      _ => query.copyWith(type: 'commercial', clearPurpose: true),
    };
    load();
  }

  void removeFilter(String key) {
    query = ListingQuery(
        q: key == 'q' ? null : query.q,
        area: key == 'area' ? null : query.area,
        district: key == 'district' ? null : query.district,
        purpose: key == 'purpose' ? null : query.purpose,
        type: key == 'type' ? null : query.type,
        minPrice: query.minPrice,
        maxPrice: query.maxPrice,
        bedrooms: query.bedrooms,
        bathrooms: query.bathrooms,
        amenities: query.amenities,
        verified: query.verified,
        featured: query.featured,
        country: query.country,
        region: query.region,
        latitude: query.latitude,
        longitude: query.longitude,
        radius: query.radius,
        limit: query.limit,
        sort: query.sort);
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
        child: RefreshIndicator(
            onRefresh: () => swipe ? Future.value() : load(refresh: true),
            child: CustomScrollView(
              physics: swipe
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              controller: scroll,
              slivers: [
                SliverAppBar(
                  floating: !swipe,
                  pinned: true,
                  title: const Text('Discover'),
                  actions: [
                    if (!swipe &&
                        context.watch<CompareController>().ids.length == 2)
                      IconButton(
                          tooltip: 'Open comparison',
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CompareScreen())),
                          icon: const Icon(Icons.balance)),
                    IconButton(
                        tooltip: 'Refresh properties',
                        onPressed: loading ? null : () => load(refresh: true),
                        icon: const Icon(Icons.refresh)),
                    IconButton(
                      tooltip: 'Search',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      ),
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                if (!swipe)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 54 *
                          MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final labels = [
                            'Buy',
                            'Rent',
                            'Short Stay',
                            'Land',
                            'Commercial',
                          ];
                          final selected = (labels[i] == 'Buy' &&
                                  query.purpose == 'sale') ||
                              (labels[i] == 'Rent' &&
                                  query.purpose == 'rent') ||
                              (labels[i] == 'Short Stay' &&
                                  query.purpose == 'short_stay') ||
                              (labels[i] == 'Land' && query.type == 'land') ||
                              (labels[i] == 'Commercial' &&
                                  query.type == 'commercial');
                          return ChoiceChip(
                            label: Text(labels[i]),
                            selected: selected,
                            onSelected: (_) => purpose(labels[i]),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: 5,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: swipe
                            ? Row(children: [
                                Expanded(child: _mode()),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                    tooltip: 'Filters',
                                    onPressed: _filters,
                                    icon: const Icon(Icons.tune)),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                    tooltip: 'Sort',
                                    onPressed: _sort,
                                    icon: const Icon(Icons.swap_vert))
                              ])
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                    OutlinedButton.icon(
                                        onPressed: _filters,
                                        icon: const Icon(Icons.tune),
                                        label: const Text('Filters')),
                                    _mode(),
                                    OutlinedButton.icon(
                                        onPressed: _sort,
                                        icon: const Icon(Icons.swap_vert),
                                        label: const Text('Sort')),
                                    Text(
                                        '$total ${total == 1 ? 'home' : 'homes'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium)
                                  ]))),
                if (!swipe &&
                    [
                      query.q,
                      query.area,
                      query.district,
                      query.purpose,
                      query.type
                    ].any((value) => value?.isNotEmpty == true))
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final entry in {
                              'q': query.q,
                              'area': query.area,
                              'district': query.district,
                              'purpose': query.purpose,
                              'type': query.type
                            }.entries)
                              if (entry.value?.isNotEmpty == true)
                                InputChip(
                                    label:
                                        Text(entry.value!.replaceAll('_', ' ')),
                                    deleteButtonTooltipMessage:
                                        'Remove ${entry.key} filter',
                                    onDeleted: () => removeFilter(entry.key)),
                          ]))),
                if (loading && items.isNotEmpty)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                if (failure != null && items.isNotEmpty)
                  SliverToBoxAdapter(
                      child: TextButton(
                          onPressed: () => load(refresh: true),
                          child: const Text(
                              'Refresh failed. Existing results kept. Retry'))),
                if (loading && items.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.list(
                      children: const [
                        PropertySkeleton(),
                        SizedBox(height: 14),
                        PropertySkeleton(),
                      ],
                    ),
                  )
                else if (failure != null && items.isEmpty)
                  SliverFillRemaining(
                    child:
                        AppErrorState(message: failure!.message, onRetry: load),
                  )
                else if (items.isEmpty)
                  const SliverFillRemaining(
                    child: AppEmptyState(
                      icon: Icons.home_work_outlined,
                      title: 'No properties found',
                      message: 'Clear a filter or try a nearby location.',
                    ),
                  )
                else if (swipe)
                  SliverFillRemaining(
                      hasScrollBody: true,
                      child: SwipeDiscovery(
                          key: ValueKey(loadEpoch),
                          items: items,
                          active: widget.active,
                          hasMore: query.page < pages,
                          loadingMore: loadingMore,
                          onMore: more,
                          position: swipePosition))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver:
                        SliverLayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.crossAxisExtent >= 720
                          ? 3
                          : constraints.crossAxisExtent >= 520
                              ? 2
                              : 1;
                      final rows = (items.length / columns).ceil();
                      return SliverList.separated(
                        itemCount: rows + (loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 24),
                        itemBuilder: (context, row) {
                          if (row == rows) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var column = 0;
                                  column < columns;
                                  column++) ...[
                                if (column > 0) const SizedBox(width: 14),
                                Expanded(
                                    child: row * columns + column < items.length
                                        ? _card(context, row * columns + column)
                                        : const SizedBox.shrink()),
                              ],
                            ],
                          );
                        },
                      );
                    }),
                  ),
              ],
            )),
      ));

  Widget _mode() => SegmentedButton<bool>(
      style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10)),
          textStyle:
              WidgetStatePropertyAll(Theme.of(context).textTheme.labelMedium)),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: false, label: Text('Grid')),
        ButtonSegment(value: true, label: Text('Swipe'))
      ],
      selected: {swipe},
      onSelectionChanged: (value) {
        if (scroll.hasClients) scroll.jumpTo(0);
        setState(() => swipe = value.single);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scroll.hasClients) scroll.jumpTo(0);
        });
      });
  Future<void> _filters() async {
    final result = await FilterSheet.show(context, query);
    if (result != null && mounted) {
      query = result;
      load();
    }
  }

  Future<void> _sort() async {
    final result = await showModalBottomSheet<ListingSort>(
        context: context, builder: (_) => _SortSheet(selected: query.sort));
    if (result != null && mounted) {
      query = query.copyWith(sort: result);
      load();
    }
  }

  Widget _card(BuildContext context, int i) {
    if (i == items.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final item = items[i];
    return PropertyCard(
      property: item,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PropertyDetailScreen(
            idOrSlug: item.slug,
            initial: item,
          ),
        ),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.selected});
  final ListingSort selected;
  @override
  Widget build(BuildContext context) {
    final options = [
      (ListingSort.newest, 'Newest'),
      (ListingSort.oldest, 'Oldest'),
      (ListingSort.priceAsc, 'Price: low to high'),
      (ListingSort.priceDesc, 'Price: high to low'),
      (ListingSort.popular, 'Popular'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort properties',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            RadioGroup<ListingSort>(
              groupValue: selected,
              onChanged: (value) => Navigator.pop(context, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (item) => RadioListTile<ListingSort>(
                        value: item.$1,
                        title: Text(item.$2),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
