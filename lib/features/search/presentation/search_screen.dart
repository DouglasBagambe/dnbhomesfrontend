import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/states.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../listings/data/listings_repository.dart';
import '../../listings/domain/property.dart';
import '../../listings/presentation/property_card.dart';
import '../../listings/presentation/property_detail_screen.dart';
import '../recent_searches.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  final historyStore = RecentSearches();
  Timer? debounce;
  List<Property> results = [];
  List<String> history = [];
  bool loading = false;
  ApiFailure? failure;

  @override
  void initState() {
    super.initState();
    historyStore.getAll().then((value) {
      if (mounted) setState(() => history = value);
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void changed(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () => search(value));
    setState(() {});
  }

  Future<void> search(String value) async {
    final term = value.trim();
    if (term.length < 2) {
      setState(() {
        results = [];
        failure = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final page = await context.read<ListingsRepository>().list(
            ListingQuery(q: term, limit: 12),
          );
      if (!mounted || controller.text.trim() != term) return;
      await historyStore.add(term);
      setState(() {
        results = page.items;
        loading = false;
      });
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          failure = error;
          loading = false;
        });
      }
    }
  }

  void discover(String term) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoverScreen(initialQuery: ListingQuery(q: term)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: controller,
            autofocus: true,
            onChanged: changed,
            onSubmitted: discover,
            decoration: const InputDecoration(
              hintText: 'Property, location or agent',
              border: InputBorder.none,
            ),
          ),
        ),
        body: _body(),
      );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (failure != null) {
      return AppErrorState(
        message: failure!.message,
        onRetry: () => search(controller.text),
      );
    }
    if (controller.text.trim().length >= 2) {
      if (results.isEmpty) {
        return const AppEmptyState(
          icon: Icons.search_off,
          title: 'No matching properties',
          message: 'Try a broader location, property type or price.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: results.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          if (index == results.length) {
            return TextButton(
              onPressed: () => discover(controller.text),
              child: const Text('See all results in Discover'),
            );
          }
          final item = results[index];
          return PropertyCard(
            property: item,
            layout: PropertyCardLayout.compact,
            showCompare: false,
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
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text('Recent searches',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              TextButton(
                onPressed: () async {
                  await historyStore.clear();
                  if (mounted) setState(() => history = []);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: history
                .map((item) => ActionChip(
                      label: Text(item),
                      onPressed: () {
                        controller.text = item;
                        search(item);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 26),
        ],
        Text('Popular locations',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...['Kampala', 'Ntinda', 'Kololo', 'Muyenga', 'Entebbe'].map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(item),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => discover(item),
          ),
        ),
        const SizedBox(height: 18),
        Text('Browse categories',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Rent', 'Buy', 'Short Stay', 'Land', 'Commercial']
              .map((item) => ActionChip(
                    label: Text(item),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiscoverScreen(
                          initialQuery: switch (item) {
                            'Rent' => const ListingQuery(purpose: 'rent'),
                            'Buy' => const ListingQuery(purpose: 'sale'),
                            'Short Stay' =>
                              const ListingQuery(purpose: 'short_stay'),
                            'Land' => const ListingQuery(type: 'land'),
                            _ => const ListingQuery(type: 'commercial'),
                          },
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
