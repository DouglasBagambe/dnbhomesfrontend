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
import 'features/listings/presentation/property_detail_screen.dart';
import 'features/navigation/app_shell.dart';

class HomesApp extends StatelessWidget {
  const HomesApp({super.key, this.apiClient});
  final ApiClient? apiClient;
  @override
  Widget build(BuildContext context) {
    final api = apiClient ?? ApiClient();
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
          routes: {'/': (_) => const AppShell()},
          onGenerateRoute: _propertyRoute,
          onGenerateInitialRoutes: (initialRoute) {
            final property = _propertyRoute(RouteSettings(name: initialRoute));
            return [
              MaterialPageRoute(
                settings: const RouteSettings(name: '/'),
                builder: (_) => const AppShell(),
              ),
              if (property != null) property,
            ];
          },
        ),
      ),
    );
  }

  Route<dynamic>? _propertyRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri == null ||
        ((uri.hasScheme || uri.hasAuthority) &&
            (uri.scheme != 'https' || uri.host != 'dnbhomes.com'))) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length != 2 ||
        segments.first != 'properties' ||
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9-]*$').hasMatch(segments.last)) {
      return null;
    }
    final identifier =
        RegExp(r'-([a-fA-F0-9]{24})$').firstMatch(segments.last)?.group(1) ??
            segments.last;
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => PropertyDetailScreen(idOrSlug: identifier),
    );
  }
}
