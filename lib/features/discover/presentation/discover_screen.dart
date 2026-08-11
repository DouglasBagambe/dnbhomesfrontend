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

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.initialQuery = const ListingQuery()});
  final ListingQuery initialQuery;
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late ListingQuery query = widget.initialQuery;
  final items = <Property>[];
  bool loading = true, loadingMore = false;
  ApiFailure? failure;
  int total = 0, pages = 0;
  final scroll = ScrollController();
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

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final page = await context.read<ListingsRepository>().list(
            query.copyWith(page: 1),
          );
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(page.items);
        query = query.copyWith(page: 1);
        total = page.total;
        pages = page.pages;
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

  Future<void> more() async {
    setState(() => loadingMore = true);
    try {
      final next = query.copyWith(page: query.page + 1);
      final page = await context.read<ListingsRepository>().list(next);
      if (!mounted) return;
      setState(() {
        items.addAll(page.items);
        query = next;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingMore = false);
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

  @override
  Widget build(BuildContext context) => SafeArea(
        child: CustomScrollView(
          controller: scroll,
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              title: const Text('Discover'),
              actions: [
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
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final labels = [
                      'Buy',
                      'Rent',
                      'Short Stay',
                      'Land',
                      'Commercial',
                    ];
                    final selected =
                        (labels[i] == 'Buy' && query.purpose == 'sale') ||
                            (labels[i] == 'Rent' && query.purpose == 'rent') ||
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
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilterSheet.show(context, query);
                        if (result != null) {
                          query = result;
                          load();
                        }
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('Filters'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await showModalBottomSheet<ListingSort>(
                          context: context,
                          builder: (_) => _SortSheet(selected: query.sort),
                        );
                        if (result != null) {
                          query = query.copyWith(sort: result);
                          load();
                        }
                      },
                      icon: const Icon(Icons.swap_vert),
                      label: const Text('Sort'),
                    ),
                    const Spacer(),
                    Text(
                      '$total results',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            if (loading)
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
            else if (failure != null)
              SliverFillRemaining(
                child: AppErrorState(message: failure!.message, onRetry: load),
              )
            else if (items.isEmpty)
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'No properties found',
                  message: 'Clear a filter or try a nearby location.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 720
                        ? 3
                        : MediaQuery.sizeOf(context).width >= 520
                            ? 2
                            : 1,
                    childAspectRatio:
                        MediaQuery.sizeOf(context).width >= 520 ? .72 : 1.05,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: items.length + (loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == items.length)
                      return const Center(child: CircularProgressIndicator());
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
                  },
                ),
              ),
          ],
        ),
      );
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
