import 'dart:async';

import 'media_gallery.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/states.dart';
import '../../agents/presentation/agent_card.dart';
import '../../bookings/presentation/viewing_request_screen.dart';
import '../../compare/compare_controller.dart';
import '../../favorites/favorites_controller.dart';
import '../data/listings_repository.dart';
import '../domain/property.dart';
import 'property_carousel.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({
    super.key,
    required this.idOrSlug,
    this.initial,
  });

  final String idOrSlug;
  final Property? initial;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  Property? property;
  ApiFailure? failure;
  bool loading = true;
  List<Property> similar = [];

  @override
  void initState() {
    super.initState();
    property = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final repo = context.read<ListingsRepository>();
      final detail = await repo.get(widget.idOrSlug);
      final related = await repo.list(ListingQuery(
        type: detail.type,
        area: detail.location.area.isEmpty ? null : detail.location.area,
        limit: 6,
      ));
      if (!mounted) return;
      setState(() {
        property = detail;
        similar = related.items.where((item) => item.id != detail.id).toList();
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

  Future<void> open(String value) async {
    final uri = Uri.parse(value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> share(Property item) => SharePlus.instance.share(
        ShareParams(
          text: 'View ${item.title} on Homes\n'
              'https://dnbhomes.com/properties/${item.slug}-${item.id}',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final item = property;
    if (item == null && loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message: failure?.message ?? 'Property unavailable',
          onRetry: load,
        ),
      );
    }
    final media = List<PropertyMedia>.of(item.media);
    if (item.cover != null && !media.any((m) => m.url == item.cover!.url))
      media.insert(0, item.cover!);
    return Scaffold(
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ViewingRequestScreen(property: item))),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Request a viewing'),
              ))),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.sizeOf(context).height < 500 ? 240 : 360,
            leading:
                _circle(Icons.arrow_back, 'Back', () => Navigator.pop(context)),
            actions: [
              _circle(
                  Icons.refresh, 'Refresh property', loading ? () {} : load),
              _favorite(item),
              _compare(item),
              _circle(
                  Icons.share_outlined, 'Share property', () => share(item)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: MediaGallery(
                  key: ValueKey(media.map((m) => m.url).join('|')),
                  media: media,
                  title: item.title),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loading) const LinearProgressIndicator(),
                  if (failure != null)
                    TextButton.icon(
                        onPressed: load,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                            'Refresh failed. Saved details kept. ${failure!.message}')),
                  Text(formatMoney(item.price),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 16),
                  Text(item.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 19),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(item.location.shortLabel.isEmpty
                          ? item.location.address
                          : item.location.shortLabel),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  if (item.verified)
                    Row(children: [
                      Icon(Icons.verified_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 5),
                      Expanded(
                          child: Text('Verified listing',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Theme.of(context).colorScheme.primary))),
                    ]),
                  if (item.publishedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Published ${_relative(item.publishedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  const SizedBox(height: 22),
                  _Facts(item: item),
                  const SizedBox(height: 26),
                  _contactButtons(item),
                  const SizedBox(height: 30),
                  _heading('About this property'),
                  const SizedBox(height: 10),
                  Text(item.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  if (item.amenities.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    _heading('Amenities'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.amenities
                          .map((value) => Chip(
                                avatar: const Icon(Icons.check, size: 16),
                                label: Text(value),
                              ))
                          .toList(),
                    ),
                  ],
                  if (item.location.latitude != null) ...[
                    const SizedBox(height: 30),
                    _heading('Location'),
                    const SizedBox(height: 12),
                    Container(
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 36),
                          const SizedBox(height: 8),
                          Text(item.location.address.isEmpty
                              ? item.location.shortLabel
                              : item.location.address),
                        ],
                      ),
                    ),
                  ],
                  if (item.agent != null) ...[
                    const SizedBox(height: 30),
                    _heading('Property representative'),
                    const SizedBox(height: 12),
                    AgentCard(agent: item.agent!, fallbackAgency: item.agency),
                  ],
                  const SizedBox(height: 26),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Never send money before independently verifying '
                              'the property and representative. Homes does not '
                              'guarantee availability or ownership.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (similar.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _heading('Similar properties'),
                    const SizedBox(height: 14),
                    PropertyCarousel(
                      items: similar,
                      onTap: (property) => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PropertyDetailScreen(
                                  idOrSlug: property.slug, initial: property))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButtons(Property item) => Row(children: [
        if (item.agent?.phone?.isNotEmpty == true)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => open('tel:${item.agent!.phone}'),
              icon: const Icon(Icons.call_outlined),
              label: const Text('Call'),
            ),
          ),
        if (item.agent?.whatsapp?.isNotEmpty == true) ...[
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => open(
                  'https://wa.me/${item.agent!.whatsapp!.replaceAll(RegExp(r'\D'), '')}'),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp'),
            ),
          ),
        ],
      ]);

  Widget _heading(String value) =>
      Text(value, style: Theme.of(context).textTheme.headlineSmall);

  Widget _circle(
          IconData icon, String tooltip, FutureOr<void> Function() onTap) =>
      Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onTap,
            icon: Icon(icon),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
        ),
      );

  Widget _favorite(Property item) => Consumer<FavoritesController>(
        builder: (_, value, __) => _circle(
          value.contains(item.id) ? Icons.favorite : Icons.favorite_border,
          'Favorite',
          () => value.toggle(item.id),
        ),
      );

  Widget _compare(Property item) => Consumer<CompareController>(
        builder: (_, value, __) => _circle(
          value.contains(item.id) ? Icons.balance : Icons.balance_outlined,
          'Compare',
          () async {
            final ok = await value.toggle(item.id);
            if (!ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Compare is limited to two properties.')));
            }
          },
        ),
      );

  String _relative(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    return days <= 0
        ? 'today'
        : days == 1
            ? 'yesterday'
            : '$days days ago';
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.item});

  final Property item;

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, String?)>[
      (
        Icons.bed_outlined,
        (item.bedrooms ?? 0) <= 0 ? null : '${item.bedrooms} bedrooms'
      ),
      (
        Icons.bathtub_outlined,
        (item.bathrooms ?? 0) <= 0 ? null : '${item.bathrooms} bathrooms'
      ),
      (
        Icons.square_foot_outlined,
        item.size == null ? null : '${item.size!.round()} ${item.sizeUnit}'
      ),
      (Icons.home_work_outlined, titleCase(item.type)),
    ].where((fact) => fact.$2 != null);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: facts
          .map((fact) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fact.$1, size: 19),
                    const SizedBox(width: 7),
                    Text(fact.$2!),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
