import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/states.dart';
import '../bookings_controller.dart';
import '../data/bookings_repository.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BookingsController>();
    final requests = controller.items;
    final upcoming = requests.where((item) => item.isUpcoming).toList();
    final past = requests.where((item) => !upcoming.contains(item)).toList();
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Viewing requests',
                            style: Theme.of(context).textTheme.headlineMedium)),
                    IconButton(
                        tooltip: 'Refresh viewing status',
                        onPressed: controller.refreshing
                            ? null
                            : () => controller
                                .refresh(context.read<BookingsRepository>()),
                        icon: const Icon(Icons.refresh))
                  ]),
                  if (controller.refreshing) const LinearProgressIndicator(),
                  if (controller.feedback != null)
                    Text(controller.feedback!,
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 5),
                  Text(
                    'Viewing requests saved on this device',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Upcoming / Pending'),
                Tab(text: 'Past / Cancelled'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  RefreshIndicator(
                      onRefresh: () => controller
                          .refresh(context.read<BookingsRepository>()),
                      child: _list(context, upcoming, true)),
                  RefreshIndicator(
                      onRefresh: () => controller
                          .refresh(context.read<BookingsRepository>()),
                      child: _list(context, past, false)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<ViewingRequest> items,
    bool upcoming,
  ) {
    if (items.isEmpty)
      return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppEmptyState(
              icon: Icons.calendar_month_outlined,
              title: upcoming ? 'No viewing requests' : 'No past requests',
              message: upcoming
                  ? 'When you request a viewing, its server reference and pending status will appear here.'
                  : 'Past and cancelled local requests will appear here.',
            )
          ]);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                width: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.reference,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(titleCase(item.status),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat(
                    'EEE, d MMM yyyy · h:mm a',
                  ).format(item.scheduledAt.toLocal()),
                ),
                const SizedBox(height: 5),
                Text(
                  item.canSync
                      ? 'Server status · Saved on this device'
                      : 'Live refresh unavailable for this older request',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
