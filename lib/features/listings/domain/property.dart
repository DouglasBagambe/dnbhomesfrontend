class PropertyPrice {
  const PropertyPrice({
    required this.amount,
    required this.currency,
    required this.period,
  });
  final double amount;
  final String currency;
  final String period;
  factory PropertyPrice.fromJson(Map<String, dynamic>? json) => PropertyPrice(
        amount: (json?['amount'] as num?)?.toDouble() ?? 0,
        currency: json?['currency'] as String? ?? 'UGX',
        period: json?['period'] as String? ?? 'total',
      );
}

class PropertyLocation {
  const PropertyLocation({
    required this.country,
    required this.region,
    required this.district,
    required this.area,
    required this.address,
    this.latitude,
    this.longitude,
  });
  final String country, region, district, area, address;
  final double? latitude, longitude;
  String get shortLabel =>
      [area, district].where((v) => v.isNotEmpty).join(', ');
  factory PropertyLocation.fromJson(Map<String, dynamic>? json) {
    final coords = (json?['coordinates']
        as Map<String, dynamic>?)?['coordinates'] as List?;
    return PropertyLocation(
      country: json?['country'] as String? ?? '',
      region: json?['region'] as String? ?? '',
      district: json?['district'] as String? ?? '',
      area: json?['area'] as String? ?? '',
      address: json?['address'] as String? ?? '',
      longitude: coords != null && coords.isNotEmpty
          ? (coords[0] as num?)?.toDouble()
          : null,
      latitude: coords != null && coords.length > 1
          ? (coords[1] as num?)?.toDouble()
          : null,
    );
  }
}

class PropertyMedia {
  const PropertyMedia({required this.url, required this.type, this.alt});
  final String url, type;
  final String? alt;
  factory PropertyMedia.fromJson(Map<String, dynamic> json) => PropertyMedia(
        url: json['url'] as String? ?? '',
        type: json['type'] as String? ?? 'image',
        alt: json['alt'] as String?,
      );
}

class Agency {
  const Agency({
    required this.id,
    required this.name,
    this.logo,
    this.phone,
    this.email,
    this.website,
    required this.verificationStatus,
  });
  final String id, name, verificationStatus;
  final String? logo, phone, email, website;
  bool get verified => verificationStatus == 'verified';
  factory Agency.fromJson(Map<String, dynamic>? j) => Agency(
        id: j?['_id'] as String? ?? '',
        name: j?['name'] as String? ?? '',
        logo: j?['logo'] as String?,
        phone: j?['phone'] as String?,
        email: j?['email'] as String?,
        website: j?['website'] as String?,
        verificationStatus: j?['verificationStatus'] as String? ?? 'unverified',
      );
}

class Agent {
  const Agent({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.email,
    this.photo,
    this.agency,
    required this.verificationStatus,
  });
  final String id, name, verificationStatus;
  final String? phone, whatsapp, email, photo;
  final Agency? agency;
  bool get verified => verificationStatus == 'verified';
  factory Agent.fromJson(Map<String, dynamic>? j) => Agent(
        id: j?['_id'] as String? ?? '',
        name: j?['name'] as String? ?? '',
        phone: j?['phone'] as String?,
        whatsapp: j?['whatsapp'] as String?,
        email: j?['email'] as String?,
        photo: j?['photo'] as String?,
        agency: j?['agency'] is Map<String, dynamic>
            ? Agency.fromJson(j?['agency'] as Map<String, dynamic>)
            : null,
        verificationStatus: j?['verificationStatus'] as String? ?? 'unverified',
      );
}

class Property {
  const Property({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.purpose,
    required this.type,
    required this.price,
    required this.location,
    required this.media,
    this.cover,
    this.agent,
    this.agency,
    required this.amenities,
    required this.tags,
    this.bedrooms,
    this.bathrooms,
    this.size,
    required this.sizeUnit,
    required this.featured,
    required this.verificationStatus,
    required this.status,
    this.publishedAt,
    required this.viewCount,
  });
  final String id,
      slug,
      title,
      description,
      purpose,
      type,
      sizeUnit,
      verificationStatus,
      status;
  final PropertyPrice price;
  final PropertyLocation location;
  final List<PropertyMedia> media;
  final PropertyMedia? cover;
  final Agent? agent;
  final Agency? agency;
  final List<String> amenities, tags;
  final int? bedrooms, bathrooms;
  final double? size;
  final bool featured;
  final DateTime? publishedAt;
  final int viewCount;
  bool get verified => verificationStatus == 'verified';
  String? get imageUrl => cover?.url.isNotEmpty == true
      ? cover!.url
      : media
          .where((item) => item.type == 'image' && item.url.isNotEmpty)
          .firstOrNull
          ?.url;
  factory Property.fromJson(Map<String, dynamic> j) {
    final media = (j['media'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PropertyMedia.fromJson)
        .toList();
    return Property(
      id: j['_id'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      title: j['title'] as String? ?? 'Untitled property',
      description: j['description'] as String? ?? '',
      purpose: j['purpose'] as String? ?? '',
      type: j['type'] as String? ?? 'other',
      price: PropertyPrice.fromJson(j['price'] as Map<String, dynamic>?),
      location: PropertyLocation.fromJson(
        j['location'] as Map<String, dynamic>?,
      ),
      media: media,
      cover: j['cover'] is Map<String, dynamic>
          ? PropertyMedia.fromJson(j['cover'] as Map<String, dynamic>)
          : null,
      agent: j['agent'] is Map<String, dynamic>
          ? Agent.fromJson(j['agent'] as Map<String, dynamic>)
          : null,
      agency: j['agency'] is Map<String, dynamic>
          ? Agency.fromJson(j['agency'] as Map<String, dynamic>)
          : null,
      amenities:
          (j['amenities'] as List? ?? const []).whereType<String>().toList(),
      tags: (j['tags'] as List? ?? const []).whereType<String>().toList(),
      bedrooms: (j['bedrooms'] as num?)?.toInt(),
      bathrooms: (j['bathrooms'] as num?)?.toInt(),
      size: (j['size'] as num?)?.toDouble(),
      sizeUnit: j['sizeUnit'] as String? ?? 'sqm',
      featured: j['featured'] as bool? ?? false,
      verificationStatus: j['verificationStatus'] as String? ?? 'unverified',
      status: j['status'] as String? ?? '',
      publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
      viewCount: (j['viewCount'] as num?)?.toInt() ?? 0,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
