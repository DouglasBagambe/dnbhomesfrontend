import 'package:flutter/material.dart';
import '../domain/property.dart';
import 'property_card.dart';

/// A small, bounded recommendation set that sizes itself to its actual copy,
/// including accessibility text scaling, rather than reserving blank card space.
class PropertyCarousel extends StatelessWidget {
  const PropertyCarousel(
      {super.key,
      required this.items,
      required this.onTap,
      this.padding = EdgeInsets.zero});
  final List<Property> items;
  final ValueChanged<Property> onTap;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            PropertyCard(
                property: items[i],
                onTap: () => onTap(items[i]),
                layout: PropertyCardLayout.horizontal),
          ],
        ]),
      );
}
