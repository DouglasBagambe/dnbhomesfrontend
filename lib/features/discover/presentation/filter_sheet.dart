import 'package:flutter/material.dart';
import '../../listings/data/listings_repository.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial});
  final ListingQuery initial;
  static Future<ListingQuery?> show(BuildContext context, ListingQuery query) =>
      showModalBottomSheet<ListingQuery>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: FilterSheet(initial: query),
          ),
        ),
      );
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String? purpose = widget.initial.purpose,
      type = widget.initial.type,
      area = widget.initial.area,
      district = widget.initial.district;
  late double? min = widget.initial.minPrice, max = widget.initial.maxPrice;
  late int? beds = widget.initial.bedrooms, baths = widget.initial.bathrooms;
  late bool verified = widget.initial.verified ?? false;
  late ListingSort sort = widget.initial.sort;
  late final amenities = widget.initial.amenities.toSet();
  int reset = 0;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        heightFactor: .94,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Filters'),
            automaticallyImplyLeading: false,
            actions: [
              TextButton(onPressed: clear, child: const Text('Clear all')),
              IconButton(
                tooltip: 'Close filters',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: ListView(
            key: ValueKey(reset),
            padding: const EdgeInsets.all(20),
            children: [
              Text('Property',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              section(
                'Purpose',
                ['rent', 'sale', 'short_stay'],
                purpose,
                (v) => setState(() => purpose = v),
              ),
              section(
                'Property type',
                [
                  'apartment',
                  'house',
                  'land',
                  'commercial',
                  'hotel',
                  'guest_house',
                  'serviced_apartment',
                  'other',
                ],
                type,
                (v) => setState(() => type = v),
              ),
              Text('Location', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: area,
                onChanged: (v) => area = v,
                decoration:
                    const InputDecoration(labelText: 'Area or neighbourhood'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  initialValue: district,
                  onChanged: (v) => district = v,
                  decoration: const InputDecoration(labelText: 'District')),
              const SizedBox(height: 24),
              Text(
                'Price & space (UGX)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: min?.round().toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => min = double.tryParse(v),
                      decoration: const InputDecoration(labelText: 'Minimum'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: max?.round().toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => max = double.tryParse(v),
                      decoration: const InputDecoration(labelText: 'Maximum'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _counter('Bedrooms', beds, (v) => setState(() => beds = v)),
              _counter('Bathrooms', baths, (v) => setState(() => baths = v)),
              const SizedBox(height: 18),
              Text('Details · Amenities',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Parking', 'Security', 'Furnished', 'Pool', 'Garden']
                    .map(
                      (item) => FilterChip(
                        label: Text(item),
                        selected: amenities.contains(item),
                        onSelected: (value) => setState(
                          () => value
                              ? amenities.add(item)
                              : amenities.remove(item),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Verified listings only'),
                value: verified,
                onChanged: (v) => setState(() => verified = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ListingSort>(
                initialValue: sort,
                decoration: const InputDecoration(labelText: 'Sort'),
                items: const [
                  DropdownMenuItem(
                    value: ListingSort.newest,
                    child: Text('Newest'),
                  ),
                  DropdownMenuItem(
                    value: ListingSort.oldest,
                    child: Text('Oldest'),
                  ),
                  DropdownMenuItem(
                    value: ListingSort.priceAsc,
                    child: Text('Price: low to high'),
                  ),
                  DropdownMenuItem(
                    value: ListingSort.priceDesc,
                    child: Text('Price: high to low'),
                  ),
                  DropdownMenuItem(
                    value: ListingSort.popular,
                    child: Text('Popular'),
                  ),
                ],
                onChanged: (v) => setState(() => sort = v ?? sort),
              ),
              const SizedBox(height: 90),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: apply,
                child: const Text('Apply filters'),
              ),
            ),
          ),
        ),
      );
  Widget section(
    String title,
    List<String> items,
    String? selected,
    ValueChanged<String?> changed,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) => ChoiceChip(
                      label: Text(item.replaceAll('_', ' ')),
                      selected: selected == item,
                      onSelected: (value) => changed(value ? item : null),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
  Widget _counter(String label, int? value, ValueChanged<int?> changed) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton.outlined(
              onPressed: value == null || value <= 0
                  ? null
                  : () => changed(value - 1 == 0 ? null : value - 1),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 44,
              child: Text(
                value?.toString() ?? 'Any',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton.outlined(
              onPressed: () => changed((value ?? 0) + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );
  void clear() => setState(() {
        reset++;
        purpose = type = area = district = null;
        min = max = null;
        beds = baths = null;
        verified = false;
        sort = ListingSort.newest;
        amenities.clear();
      });
  void apply() => Navigator.pop(
        context,
        ListingQuery(
          q: reset == 0 ? widget.initial.q : null,
          country: reset == 0 ? widget.initial.country : null,
          region: reset == 0 ? widget.initial.region : null,
          featured: reset == 0 ? widget.initial.featured : null,
          latitude: reset == 0 ? widget.initial.latitude : null,
          longitude: reset == 0 ? widget.initial.longitude : null,
          radius: reset == 0 ? widget.initial.radius : null,
          limit: widget.initial.limit,
          district: district?.trim().isEmpty == true ? null : district?.trim(),
          purpose: purpose,
          type: type,
          area: area?.trim().isEmpty == true ? null : area?.trim(),
          minPrice: min,
          maxPrice: max,
          bedrooms: beds,
          bathrooms: baths,
          amenities: amenities.toList(),
          verified: verified ? true : null,
          sort: sort,
        ),
      );
}
