import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../listings/data/listings_repository.dart';
import '../../core/network/api_client.dart';
import '../listings/domain/property.dart';
import '../listings/presentation/property_card.dart';
import '../listings/presentation/property_detail_screen.dart';

class RecentHomesScreen extends StatefulWidget {
  const RecentHomesScreen({super.key, required this.ids});
  final List<String> ids;
  @override
  State<RecentHomesScreen> createState() => _RecentHomesScreenState();
}

class _RecentHomesScreenState extends State<RecentHomesScreen> {
  late Future<List<Property>> homes = load();
  Future<List<Property>> load() =>
      Future.wait(widget.ids.take(30).map((id) async {
        try {
          return await context.read<ListingsRepository>().get(id);
        } on ApiFailure catch (error) {
          if (error.statusCode == 404) return null;
          rethrow;
        }
      })).then((values) => values.whereType<Property>().toList());
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Recently viewed')),
      body: FutureBuilder<List<Property>>(
          future: homes,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Unable to load recent homes.'),
                TextButton(
                    onPressed: () => setState(() => homes = load()),
                    child: const Text('Retry'))
              ]));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            if (items.isEmpty)
              return const Center(
                  child: Text(
                      'Your recent homes will appear here when available.'));
            return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return PropertyCard(
                      property: item,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PropertyDetailScreen(
                                  idOrSlug: item.id, initial: item))));
                });
          }));
}
