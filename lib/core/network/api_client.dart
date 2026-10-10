import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

enum ApiFailureKind {
  network,
  timeout,
  unauthorized,
  validation,
  server,
  parsing,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, this.message, {this.statusCode});
  final ApiFailureKind kind;
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;
  final http.Client _client;
  final String baseUrl;
  Future<String?> Function()? consumerToken;
  Future<void> Function(String)? onConsumerToken;
  Future<void> Function()? onConsumerExpired;
  static const timeout = Duration(seconds: 15);
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
    Map<String, String> headers = const {},
  }) =>
      _send('GET', path, query: query, headers: headers);
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
  }) =>
      _send('POST', path, body: body, headers: headers);
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value?.isNotEmpty == true) entry.key: entry.value!,
      },
    );
    try {
      final privateRequest = path.startsWith('/consumer/') ||
          path == '/bookings' ||
          path.startsWith('/auth/consumer/');
      final session = privateRequest ? await consumerToken?.call() : null;
      final requestHeaders = <String, String>{
        if (session != null) 'Authorization': 'Bearer $session',
        ...headers,
      };
      final response = await (method == 'GET'
              ? _client.get(
                  uri,
                  headers: {'Accept': 'application/json', ...requestHeaders},
                )
              : _client.post(
                  uri,
                  headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    ...requestHeaders,
                  },
                  body: jsonEncode(body),
                ))
          .timeout(timeout);
      final issued = response.headers['set-auth-token'];
      if (privateRequest &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          issued != null)
        await onConsumerToken?.call(Uri.decodeComponent(issued));
      if (session != null &&
          response.statusCode == 401 &&
          (path.startsWith('/consumer/') || path == '/bookings'))
        await onConsumerExpired?.call();
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) return decoded;
      final message = decoded is Map
          ? ((decoded['error'] as Map?)?['message'] as String? ??
              decoded['message'] as String? ??
              'Request failed')
          : 'Request failed';
      if (response.statusCode == 400)
        throw ApiFailure(
          ApiFailureKind.validation,
          message,
          statusCode: response.statusCode,
        );
      if (response.statusCode == 401 || response.statusCode == 403)
        throw ApiFailure(
          ApiFailureKind.unauthorized,
          message,
          statusCode: response.statusCode,
        );
      if (response.statusCode >= 500)
        throw ApiFailure(
          ApiFailureKind.server,
          message,
          statusCode: response.statusCode,
        );
      throw ApiFailure(
        ApiFailureKind.validation,
        message,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const ApiFailure(
        ApiFailureKind.timeout,
        'The request took too long. Please try again.',
      );
    } on http.ClientException {
      throw const ApiFailure(
        ApiFailureKind.network,
        'Unable to connect. Check your internet connection.',
      );
    } on FormatException {
      throw const ApiFailure(
        ApiFailureKind.parsing,
        'The server returned an unexpected response.',
      );
    }
  }

  void close() => _client.close();
}
