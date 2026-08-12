import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/states.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/domain/property.dart';
import '../../listings/presentation/property_card.dart';
import '../../listings/presentation/property_detail_screen.dart';
import '../favorites_controller.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Property> items = [];
  bool loading = false;
  ApiFailure? failure;
  Set<String> loadedIds = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ids = context.watch<FavoritesController>().ids;
    if (!_same(ids, loadedIds)) {
      loadedIds = ids;
      load(ids);
    }
  }

  bool _same(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
  Future<void> load(Set<String> ids) async {
    if (ids.isEmpty) {
      setState(() {
        items = [];
        loading = false;
        failure = null;
      });
      return;
    }
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final repo = context.read<ListingsRepository>();
      final values = await Future.wait(ids.map(repo.get));
      if (mounted && _same(ids, loadedIds))
        setState(() {
          items = values;
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

  @override
  Widget build(BuildContext context) => SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text('Saved homes',
                style: Theme.of(context).textTheme.headlineMedium)),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : failure != null
                    ? AppErrorState(
                        message: failure!.message,
                        onRetry: () => load(loadedIds))
                    : items.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.favorite_outline,
                            title: 'No saved homes',
                            message:
                                'Save homes you want to come back to. Saved homes stay on this device.')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => PropertyCard(
                                property: items[i],
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => PropertyDetailScreen(
                                            idOrSlug: items[i].slug,
                                            initial: items[i]))))))
      ]));
}
