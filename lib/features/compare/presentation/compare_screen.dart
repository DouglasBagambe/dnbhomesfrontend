import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/network/api_client.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../../core/widgets/states.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/domain/property.dart';
import '../compare_controller.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  List<Property> items = [];
  Object? error;
  bool loading = true;
  int generation = 0;
  late CompareController selection;
  @override
  void initState() {
    super.initState();
    selection = context.read<CompareController>();
    selection.addListener(selectionChanged);
    load();
  }

  void selectionChanged() => load();

  @override
  void dispose() {
    generation++;
    selection.removeListener(selectionChanged);
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      await selection.ready;
      if (!mounted || request != generation) return;
      final repo = context.read<ListingsRepository>();
      final ids = selection.ids;
      final values = await Future.wait(ids.map((id) async {
        try {
          return await repo.get(id);
        } on ApiFailure catch (e) {
          if (e.statusCode == 404) return null;
          rethrow;
        }
      }));
      if (mounted && request == generation && values.any((p) => p == null)) {
        for (var i = 0; i < values.length; i++) {
          if (values[i] == null && selection.contains(ids[i]))
            await selection.toggle(ids[i]);
        }
        return;
      }
      if (mounted && request == generation) {
        setState(() {
          items = values.whereType<Property>().toList();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && request == generation)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  void browse() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const DiscoverScreen()));

  Widget emptySelection() => AppEmptyState(
      icon: Icons.balance_outlined,
      title:
          items.isEmpty ? 'Find your two favourites' : 'Choose one more home',
      message: items.isEmpty
          ? 'Select Compare on two property pages to see them side by side. Listings that are no longer public cannot be compared.'
          : '${items.first.title} is ready. Select Compare on another property page to compare the details.',
      action: FilledButton.icon(
          onPressed: browse,
          icon: const Icon(Icons.search),
          label: const Text('Browse homes')));

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Compare properties'), actions: [
        TextButton(
            onPressed: selection.ids.isEmpty ? null : () => selection.clear(),
            child: const Text('Clear'))
      ]),
      body: loading
          ? const PropertyListSkeleton(columns: 2)
          : error != null
              ? AppErrorState(
                  message: error is ApiFailure
                      ? (error as ApiFailure).message
                      : 'Unable to load these homes. Please try again.',
                  onRetry: load)
              : items.length < 2
                  ? emptySelection()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      children: [
                          Text('Two places. A clearer choice.',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 24),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: items
                                  .map((item) => Expanded(
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    child: AspectRatio(
                                                        aspectRatio: 4 / 3,
                                                        child: item.imageUrl ==
                                                                null
                                                            ? ColoredBox(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surfaceContainerHighest,
                                                                child: const Icon(
                                                                    Icons
                                                                        .home_work_outlined))
                                                            : CachedNetworkImage(
                                                                imageUrl: item
                                                                    .imageUrl!,
                                                                fit: BoxFit
                                                                    .cover))),
                                                const SizedBox(height: 12),
                                                Text(formatMoney(item.price),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .primary)),
                                                const SizedBox(height: 8),
                                                Text(item.title,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium),
                                              ]))))
                                  .toList()),
                          const SizedBox(height: 24),
                          ...[
                            (
                              'Location',
                              items.map((p) => p.location.shortLabel).toList()
                            ),
                            (
                              'Purpose',
                              items.map((p) => titleCase(p.purpose)).toList()
                            ),
                            (
                              'Type',
                              items.map((p) => titleCase(p.type)).toList()
                            ),
                            (
                              'Bedrooms',
                              items
                                  .map((p) => p.bedrooms?.toString() ?? '—')
                                  .toList()
                            ),
                            (
                              'Bathrooms',
                              items
                                  .map((p) => p.bathrooms?.toString() ?? '—')
                                  .toList()
                            ),
                            (
                              'Size',
                              items
                                  .map((p) => p.size == null
                                      ? '—'
                                      : '${p.size!.round()} ${p.sizeUnit}')
                                  .toList()
                            ),
                            (
                              'Verified',
                              items
                                  .map((p) => p.verified ? 'Yes' : 'No')
                                  .toList()
                            ),
                            (
                              'Representative',
                              items
                                  .map((p) =>
                                      p.agent?.name ?? p.agency?.name ?? '—')
                                  .toList()
                            ),
                            (
                              'Amenities',
                              items
                                  .map((p) => p.amenities.isEmpty
                                      ? '—'
                                      : p.amenities.join(', '))
                                  .toList()
                            ),
                          ].map((row) => Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row.$1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                    const SizedBox(height: 8),
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: row.$2
                                            .map((value) => Expanded(
                                                child: Container(
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 4),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                        color: row.$2[0] != row.$2[1]
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                            : null,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12)),
                                                    child: Text(value,
                                                        style: const TextStyle(fontWeight: FontWeight.w500)))))
                                            .toList()),
                                  ]))),
                        ]));
}
