import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/formatters.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    try {
      final repo = context.read<ListingsRepository>();
      final values = await Future.wait(
          context.read<CompareController>().ids.map(repo.get));
      if (mounted) setState(() => items = values);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Compare properties'), actions: [
        TextButton(
            onPressed: () {
              context.read<CompareController>().clear();
              Navigator.pop(context);
            },
            child: const Text('Clear'))
      ]),
      body: error != null
          ? AppErrorState(message: error.toString(), onRetry: load)
          : items.length < 2
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items
                          .map((item) => Expanded(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  child: Column(children: [
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: SizedBox(
                                            height: 150,
                                            width: double.infinity,
                                            child: item.imageUrl == null
                                                ? const ColoredBox(
                                                    color: Colors.black12)
                                                : CachedNetworkImage(
                                                    imageUrl: item.imageUrl!,
                                                    fit: BoxFit.cover))),
                                    const SizedBox(height: 12),
                                    Text(item.title,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    Text(formatMoney(item.price),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary)),
                                    const SizedBox(height: 18),
                                    _row('Location', item.location.shortLabel),
                                    _row('Purpose', titleCase(item.purpose)),
                                    _row('Type', titleCase(item.type)),
                                    _row('Bedrooms',
                                        item.bedrooms?.toString() ?? '—'),
                                    _row('Bathrooms',
                                        item.bathrooms?.toString() ?? '—'),
                                    _row(
                                        'Size',
                                        item.size == null
                                            ? '—'
                                            : '${item.size!.round()} ${item.sizeUnit}'),
                                    _row('Verified',
                                        item.verified ? 'Yes' : 'No'),
                                    _row(
                                        'Agent',
                                        item.agent?.name ??
                                            item.agency?.name ??
                                            '—'),
                                    _row(
                                        'Amenities',
                                        item.amenities.isEmpty
                                            ? '—'
                                            : item.amenities.join(', '))
                                  ]))))
                          .toList())));
  Widget _row(String label, String value) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Column(children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600))
      ]));
}
