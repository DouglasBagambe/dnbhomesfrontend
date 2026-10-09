import '../../../core/network/api_client.dart';
import '../domain/property.dart';

enum ListingSort { newest, oldest, priceAsc, priceDesc, popular }

class ListingQuery {
  const ListingQuery({
    this.q,
    this.purpose,
    this.type,
    this.country,
    this.region,
    this.district,
    this.area,
    this.minPrice,
    this.maxPrice,
    this.bedrooms,
    this.bathrooms,
    this.amenities = const [],
    this.featured,
    this.verified,
    this.latitude,
    this.longitude,
    this.radius,
    this.page = 1,
    this.limit = 20,
    this.sort = ListingSort.newest,
  });
  final String? q, purpose, type, country, region, district, area;
  final double? minPrice, maxPrice, latitude, longitude, radius;
  final int? bedrooms, bathrooms;
  final List<String> amenities;
  final bool? featured, verified;
  final int page, limit;
  final ListingSort sort;
  Map<String, String?> toQuery() => {
        'q': q,
        'purpose': purpose,
        'type': type,
        'country': country,
        'region': region,
        'district': district,
        'area': area,
        'minPrice': minPrice?.toString(),
        'maxPrice': maxPrice?.toString(),
        'bedrooms': bedrooms?.toString(),
        'bathrooms': bathrooms?.toString(),
        'amenities': amenities.isEmpty ? null : amenities.join(','),
        'featured': featured?.toString(),
        'verified': verified?.toString(),
        'latitude': latitude?.toString(),
        'longitude': longitude?.toString(),
        'radius': radius?.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': switch (sort) {
          ListingSort.priceAsc => 'price_asc',
          ListingSort.priceDesc => 'price_desc',
          _ => sort.name,
        },
      };
  ListingQuery copyWith({
    String? q,
    String? purpose,
    String? type,
    String? country,
    String? region,
    String? district,
    String? area,
    double? minPrice,
    double? maxPrice,
    int? bedrooms,
    int? bathrooms,
    List<String>? amenities,
    bool? featured,
    bool? verified,
    int? page,
    int? limit,
    ListingSort? sort,
    bool clearPurpose = false,
    bool clearType = false,
  }) =>
      ListingQuery(
        q: q ?? this.q,
        purpose: clearPurpose ? null : purpose ?? this.purpose,
        type: clearType ? null : type ?? this.type,
        country: country ?? this.country,
        region: region ?? this.region,
        district: district ?? this.district,
        area: area ?? this.area,
        minPrice: minPrice ?? this.minPrice,
        maxPrice: maxPrice ?? this.maxPrice,
        bedrooms: bedrooms ?? this.bedrooms,
        bathrooms: bathrooms ?? this.bathrooms,
        amenities: amenities ?? this.amenities,
        featured: featured ?? this.featured,
        verified: verified ?? this.verified,
        page: page ?? this.page,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
      );
}

class PropertyPage {
  const PropertyPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });
  final List<Property> items;
  final int page, limit, total, pages;
  bool get hasMore => page < pages;
}

class ListingsRepository {
  ListingsRepository(this._api, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final ApiClient _api;
  final DateTime Function() _clock;
  final _cache = <String, ({DateTime expiresAt, PropertyPage page})>{};
  final _inFlight = <String, Future<PropertyPage>>{};

  Future<PropertyPage> list(ListingQuery query, {bool refresh = false}) {
    final key = Uri(queryParameters: {
      for (final entry in query.toQuery().entries)
        if (entry.value?.isNotEmpty == true) entry.key: entry.value!,
    }).query;
    final cached = _cache[key];
    if (!refresh && cached != null && _clock().isBefore(cached.expiresAt)) {
      return Future.value(cached.page);
    }
    if (!refresh && _inFlight[key] != null) return _inFlight[key]!;
    late Future<PropertyPage> pending;
    pending = _load(query).then((page) {
      if (identical(_inFlight[key], pending)) {
        _cache.remove(key);
        _cache[key] =
            (expiresAt: _clock().add(const Duration(seconds: 30)), page: page);
        if (_cache.length > 32) _cache.remove(_cache.keys.first);
      }
      return page;
    }).whenComplete(() {
      if (identical(_inFlight[key], pending)) _inFlight.remove(key);
    });
    _inFlight[key] = pending;
    return pending;
  }

  Future<PropertyPage> _load(ListingQuery query) async {
    final json = await _api.getJson('/properties', query: query.toQuery());
    final pagination = json['pagination'] as Map<String, dynamic>? ?? const {};
    return PropertyPage(
      items: List.unmodifiable((json['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Property.fromJson)),
      page: (pagination['page'] as num?)?.toInt() ?? query.page,
      limit: (pagination['limit'] as num?)?.toInt() ?? query.limit,
      total: (pagination['total'] as num?)?.toInt() ?? 0,
      pages: (pagination['pages'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Property> get(String idOrSlug) async => Property.fromJson(
        (await _api.getJson('/properties/$idOrSlug'))['data']
            as Map<String, dynamic>,
      );
}
