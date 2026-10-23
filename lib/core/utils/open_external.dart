import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launch directly: Android package visibility can make canLaunchUrl return
/// false even when a dialer/browser/mail app can handle the action.
Future<void> openExternal(BuildContext context, Uri uri) async {
  try {
    if (!const ['https', 'mailto', 'tel'].contains(uri.scheme) ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('No application available');
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No app could open this link. Please try another contact option.')));
  }
}
