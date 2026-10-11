import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';

enum ConsumerSocialProvider { google, apple }

class ConsumerSocialAuth {
  ConsumerSocialAuth(this.api);

  final ApiClient api;
  bool _googleInitialized = false;

  Future<void> signIn(ConsumerSocialProvider provider, {bool link = false}) async {
    switch (provider) {
      case ConsumerSocialProvider.google:
        await _google(link: link);
      case ConsumerSocialProvider.apple:
        await _apple(link: link);
    }
  }

  Future<void> _google({required bool link}) async {
    if (AppConfig.googleWebClientId.isEmpty) {
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Google sign-in is not configured for this build.',
      );
    }
    final signIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await signIn.initialize(
        clientId: Platform.isIOS && AppConfig.googleIosClientId.isNotEmpty
            ? AppConfig.googleIosClientId
            : null,
        serverClientId: AppConfig.googleWebClientId,
      );
      _googleInitialized = true;
    }
    if (!signIn.supportsAuthenticate()) {
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Google sign-in is not available on this device.',
      );
    }
    try {
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiFailure(
          ApiFailureKind.validation,
          'Google did not return a valid identity token.',
        );
      }
      await api.postJson(
        '/auth/consumer/${link ? 'link-social' : 'sign-in/social'}',
        {
          'provider': 'google',
          'idToken': {'token': token},
        },
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const ApiFailure(
          ApiFailureKind.validation,
          'Google sign-in was cancelled.',
        );
      }
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Google sign-in could not be completed. Please try again.',
      );
    }
  }

  Future<void> _apple({required bool link}) async {
    if (!await SignInWithApple.isAvailable()) {
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Apple sign-in is not available on this device.',
      );
    }
    final isIos = Platform.isIOS;
    if (!isIos &&
        (AppConfig.appleServiceId.isEmpty ||
            AppConfig.appleRedirectUri.isEmpty)) {
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Apple sign-in is not configured for this build.',
      );
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: isIos
            ? null
            : WebAuthenticationOptions(
                clientId: AppConfig.appleServiceId,
                redirectUri: Uri.parse(AppConfig.appleRedirectUri),
              ),
      );
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw const ApiFailure(
          ApiFailureKind.validation,
          'Apple did not return a valid identity token.',
        );
      }
      await api.postJson(
        '/auth/consumer/${link ? 'link-social' : 'sign-in/social'}',
        {
          'provider': 'apple',
          'idToken': {'token': token},
        },
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const ApiFailure(
          ApiFailureKind.validation,
          'Apple sign-in was cancelled.',
        );
      }
      throw const ApiFailure(
        ApiFailureKind.validation,
        'Apple sign-in could not be completed. Please try again.',
      );
    }
  }
}
