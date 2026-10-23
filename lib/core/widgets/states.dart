import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class PropertySkeleton extends StatelessWidget {
  const PropertySkeleton({super.key, this.horizontal = false});
  final bool horizontal;
  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: .07);
    Widget block(double height, {double? width}) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)));
    return Semantics(
        label: 'Loading property',
        child: ExcludeSemantics(
            child: Container(
                width: horizontal ? 262 : null,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(aspectRatio: 4 / 3, child: block(160)),
                      const SizedBox(height: 16),
                      block(20, width: 135),
                      const SizedBox(height: 10),
                      block(14),
                      const SizedBox(height: 8),
                      block(12, width: 100),
                      const SizedBox(height: 16),
                      block(12, width: 80),
                    ]))));
  }
}

/// Real content proportions, without fake text or a perpetual spinner.
class PropertyListSkeleton extends StatelessWidget {
  const PropertyListSkeleton({super.key, this.columns = 1});
  final int columns;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        for (var row = 0; row < 3; row++)
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 12),
                  const Expanded(child: PropertySkeleton()),
                ]
              ]))
      ]));
}

class PropertyDetailSkeleton extends StatelessWidget {
  const PropertyDetailSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: .07);
    Widget block(double height, {double? width}) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)));
    return Semantics(
        label: 'Loading property details',
        child: ExcludeSemantics(
            child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                          aspectRatio: 4 / 3, child: ColoredBox(color: color)),
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                block(28, width: 200),
                                const SizedBox(height: 16),
                                block(20),
                                const SizedBox(height: 10),
                                block(14, width: 150),
                                const SizedBox(height: 28),
                                Row(children: [
                                  for (var i = 0; i < 3; i++) ...[
                                    if (i > 0) const SizedBox(width: 12),
                                    Expanded(child: block(60))
                                  ]
                                ]),
                                const SizedBox(height: 28),
                                block(18, width: 110),
                                const SizedBox(height: 16),
                                block(12),
                                const SizedBox(height: 8),
                                block(12),
                                const SizedBox(height: 8),
                                block(12, width: 220),
                              ]))
                    ]))));
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'We couldn’t load this',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      );
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'You’re offline. Some information may be unavailable.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
