import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bookings/presentation/bookings_screen.dart';
import '../compare/compare_controller.dart';
import '../compare/presentation/compare_screen.dart';
import '../discover/presentation/discover_screen.dart';
import '../favorites/presentation/favorites_screen.dart';
import '../home/presentation/home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  final visited = <int>{0};
  final pages = const [
    HomeScreen(),
    DiscoverScreen(),
    FavoritesScreen(),
    BookingsScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    final compare = context.watch<CompareController>();
    return Scaffold(
      body: IndexedStack(index: index, children: [
        for (var i = 0; i < pages.length; i++)
          visited.contains(i)
              ? i == 1
                  ? DiscoverScreen(active: index == 1)
                  : pages[i]
              : const SizedBox.shrink(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() {
          visited.add(value);
          index = value;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Viewings',
          ),
        ],
      ),
      floatingActionButton: compare.ids.length == 2 && index != 1
          ? FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompareScreen()),
              ),
              icon: const Icon(Icons.balance_outlined),
              label: const Text('Compare 2 homes'),
              style: FilledButton.styleFrom(elevation: 0),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
