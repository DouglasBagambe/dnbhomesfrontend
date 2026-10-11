import '../../../core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum ContentType { help, safety, contact, privacy, terms, about }

class SimpleContentScreen extends StatelessWidget {
  const SimpleContentScreen({super.key, required this.type});
  final ContentType type;
  @override
  Widget build(BuildContext context) {
    final (title, content) = switch (type) {
      ContentType.help => (
          'Help',
          'Search or browse published listings, save favorites locally, compare two properties, and submit a viewing request. A viewing remains pending until the representative confirms it.',
        ),
      ContentType.safety => (
          'Safety tips',
          'Independently verify every property and representative. Visit in person where possible. Never transfer money before due diligence. Homes does not guarantee ownership or availability.',
        ),
      ContentType.contact => (
          'Contact',
          'For product support, contact dnb Homes at dnbtechnologies@gmail.com.',
        ),
      ContentType.privacy => (
          'Privacy policy',
          'Homes processes property discovery requests and the contact details you submit for viewing requests. Favorites and minimized viewing-request records are stored locally on this device. Optional accounts synchronize Saved, Compare and account-owned Viewings. Account offers session revocation and deletion. Deletion erases synced account state and anonymizes associated operational viewing records. Verification/reset messages use a transactional email provider. Full policy: ${AppConfig.websiteUrl}/privacy',
        ),
      ContentType.terms => (
          'Terms of service',
          'Homes connects property seekers with representatives. Listings and viewing requests do not guarantee availability, ownership, pricing, or confirmation. Guest state is device-local; optional accounts sync supported state. Full terms: ${AppConfig.websiteUrl}/terms',
        ),
      ContentType.about => (
          'About Homes',
          'Homes is the consumer property discovery product operated by dnb Homes. It helps people discover property, assess listings, save and compare options, and request viewings.',
        ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(content, style: Theme.of(context).textTheme.bodyLarge),
          if (type == ContentType.contact)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: FilledButton.icon(
                onPressed: () =>
                    launchUrl(Uri.parse('mailto:dnbtechnologies@gmail.com')),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Email support'),
              ),
            ),
        ],
      ),
    );
  }
}
