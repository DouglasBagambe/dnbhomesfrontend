import 'dart:math';
import '../../../core/network/api_client.dart';

DateTime ugandaViewingTime(DateTime wallTime) => DateTime.utc(wallTime.year,
        wallTime.month, wallTime.day, wallTime.hour, wallTime.minute)
    .subtract(const Duration(hours: 3));

class ViewingRequestInput {
  const ViewingRequestInput({
    required this.propertyId,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    required this.scheduledAt,
    this.duration = 60,
    this.notes,
  });
  final String propertyId, guestName, guestEmail, guestPhone;
  final DateTime scheduledAt;
  final int duration;
  final String? notes;
  void validate() {
    if (guestName.trim().length < 2)
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Enter your full name.',
      );
    if (!guestEmail.contains('@'))
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Enter a valid email address.',
      );
    if (guestPhone.replaceAll(RegExp(r'\D'), '').length < 9)
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Enter a valid phone number.',
      );
    if (!scheduledAt.isAfter(DateTime.now()))
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Choose a future date and time.',
      );
  }
}

class ViewingRequest {
  const ViewingRequest({
    required this.id,
    required this.reference,
    required this.propertyId,
    required this.scheduledAt,
    required this.status,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    this.statusAccessToken,
    this.propertyTitle = '',
  });
  final String id,
      reference,
      propertyId,
      status,
      guestName,
      guestEmail,
      guestPhone;
  final DateTime scheduledAt;
  final String propertyTitle;
  final String? statusAccessToken;
  bool get canSync => statusAccessToken?.isNotEmpty == true && id.isNotEmpty;
  bool get isUpcoming =>
      scheduledAt.isAfter(DateTime.now()) &&
      ["pending", "confirmed"].contains(status);
  Map<String, dynamic> toJson() => {
        'id': id,
        'statusAccessToken': statusAccessToken,
        'reference': reference,
        'propertyId': propertyId,
        'propertyTitle': propertyTitle,
        'scheduledAt': scheduledAt.toIso8601String(),
        'status': status,
        'guestName': guestName,
        'guestEmail': guestEmail,
        'guestPhone': guestPhone,
      };
  factory ViewingRequest.fromJson(Map<String, dynamic> j) => ViewingRequest(
        statusAccessToken: j['statusAccessToken'] as String?,
        propertyTitle: j['propertyTitle'] as String? ?? '',
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        reference: j['reference'] as String? ?? '',
        propertyId: j['property'] is String
            ? j['property'] as String
            : j['propertyId'] as String? ?? '',
        scheduledAt: DateTime.parse(j['scheduledAt'] as String),
        status: j['status'] as String? ?? 'pending',
        guestName: j['guestName'] as String? ?? '',
        guestEmail: j['guestEmail'] as String? ?? '',
        guestPhone: j['guestPhone'] as String? ?? '',
      );
}

class BookingsRepository {
  BookingsRepository(this._api);
  final ApiClient _api;
  Future<ViewingRequest> refresh(ViewingRequest current) async {
    if (!current.canSync) return current;
    final response = await _api.getJson(
        '/bookings/${Uri.encodeComponent(current.id)}/status',
        headers: {'X-Viewing-Token': current.statusAccessToken!});
    final data = response['data'] as Map<String, dynamic>;
    return ViewingRequest.fromJson({
      ...current.toJson(),
      'status': data['status'],
      'scheduledAt': data['scheduledAt']
    });
  }

  Future<ViewingRequest> requestViewing(ViewingRequestInput input,
      {String? idempotencyKey}) async {
    input.validate();
    final key = idempotencyKey ??
        '${input.propertyId}-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final json = await _api.postJson(
      '/bookings',
      {
        'property': input.propertyId,
        'guestName': input.guestName.trim(),
        'guestEmail': input.guestEmail.trim(),
        'guestPhone': input.guestPhone.trim(),
        'scheduledAt': input.scheduledAt.toUtc().toIso8601String(),
        'duration': input.duration,
        if (input.notes?.trim().isNotEmpty == true)
          'notes': input.notes!.trim(),
      },
      headers: {'Idempotency-Key': key},
    );
    return ViewingRequest.fromJson(json['data'] as Map<String, dynamic>);
  }
}
