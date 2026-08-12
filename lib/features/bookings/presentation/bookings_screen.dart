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
    final requests = context.watch<BookingsController>().items;
    final upcoming = requests
        .where(
          (item) =>
              item.scheduledAt.isAfter(DateTime.now()) &&
              item.status != 'cancelled',
        )
        .toList();
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
                  Text(
                    'Viewing requests',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
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
              tabs: [
                Tab(text: 'Upcoming / Pending'),
                Tab(text: 'Past / Cancelled'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _list(context, upcoming, true),
                  _list(context, past, false),
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
      return AppEmptyState(
        icon: Icons.calendar_month_outlined,
        title: upcoming ? 'No viewing requests' : 'No past requests',
        message: upcoming
            ? 'When you request a viewing, its server reference and pending status will appear here.'
            : 'Past and cancelled local requests will appear here.',
      );
    return ListView.separated(
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
                    Chip(label: Text(titleCase(item.status))),
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
                  'Stored locally · Not synced across devices',
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
