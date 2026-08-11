import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/network/api_client.dart';
import 'core/state/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/bookings/bookings_controller.dart';
import 'features/bookings/data/bookings_repository.dart';
import 'features/compare/compare_controller.dart';
import 'features/favorites/favorites_controller.dart';
import 'features/listings/data/listings_repository.dart';
import 'features/navigation/app_shell.dart';

class HomesApp extends StatelessWidget {
  const HomesApp({super.key});
  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider(create: (_) => ListingsRepository(api)),
        Provider(create: (_) => BookingsRepository(api)),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => FavoritesController()),
        ChangeNotifierProvider(create: (_) => CompareController()),
        ChangeNotifierProvider(create: (_) => BookingsController()),
      ],
      child: Consumer<ThemeController>(
        builder: (_, theme, __) => MaterialApp(
          title: 'Homes',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          home: const AppShell(),
        ),
      ),
    );
  }
}
