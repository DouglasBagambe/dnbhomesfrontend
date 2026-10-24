import 'dart:math';
import 'package:flutter/foundation.dart';
import '../listings/data/listings_repository.dart';
import '../listings/domain/property.dart';

class TourClip {
  const TourClip(this.property, this.media);
  final Property property;
  final List<PropertyMedia> media;
  String get id => property.id;
}

class TourLocation {
  const TourLocation(this.area, this.district);
  final String area, district;
  String get label => [area, district].where((s) => s.isNotEmpty).join(', ');
  String get key => '$area|$district';
}

/// Scans real published inventory incrementally. Photo-only properties never enter this feed.
/// Replace the page source with a dedicated feed API later without changing UI.
class ToursFeed extends ChangeNotifier {
  ToursFeed(this.repository, {Random? random}) : random = random ?? Random();
  final ListingsRepository repository;
  final Random random;
  final clips = <TourClip>[];
  final locations = <String, TourLocation>{};
  final _seen = <String>{};
  TourLocation? location;
  bool busy = false, hasMore = true, disposed = false;
  String? error;
  int page = 0, _epoch = 0;

  static List<TourClip> videos(Iterable<Property> properties) => [
        for (final property in properties)
          if (property.status == 'published' &&
              property.media.any((m) => m.type == 'video' && _safeUrl(m.url)))
            TourClip(
                property,
                List.unmodifiable([
                  ...property.media
                      .where((m) => m.type == 'video' && _safeUrl(m.url)),
                  ...property.media
                      .where((m) => m.type == 'image' && _safeUrl(m.url)),
                ].fold<List<PropertyMedia>>([], (all, media) {
                  if (!all.any((m) => m.url == media.url)) all.add(media);
                  return all;
                }))),
      ];
  static bool _safeUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<void> select(TourLocation? value) async {
    _epoch++;
    location = value;
    page = 0;
    busy = false;
    hasMore = true;
    error = null;
    clips.clear();
    _seen.clear();
    await more();
  }

  Future<void> more() async {
    if (busy || !hasMore || disposed) return;
    final epoch = _epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      // Bound each scan so sparse video inventory never locks up the screen.
      // The UI offers Continue searching when more catalogue pages remain.
      for (var scan = 0; scan < 4; scan++) {
        final result = await repository.list(
            ListingQuery(
                page: page + 1,
                limit: 50,
                sort: ListingSort.popular,
                area: location?.area.isNotEmpty == true ? location!.area : null,
                district: location?.district.isNotEmpty == true
                    ? location!.district
                    : null),
            refresh: true);
        if (disposed || epoch != _epoch) return;
        page = result.page;
        hasMore = result.hasMore;
        for (final property in result.items) {
          final place =
              TourLocation(property.location.area, property.location.district);
          if (place.label.isNotEmpty) locations[place.key] = place;
        }
        final batch = videos(result.items)
            .where((c) => _seen.add(c.id))
            .toList()
          ..shuffle(random);
        clips.addAll(batch);
        if (batch.isNotEmpty || !hasMore) break;
      }
    } catch (_) {
      if (!disposed && epoch == _epoch)
        error = 'Couldn’t load more reels. Check your connection and retry.';
    } finally {
      if (!disposed && epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    _epoch++;
    super.dispose();
  }
}
