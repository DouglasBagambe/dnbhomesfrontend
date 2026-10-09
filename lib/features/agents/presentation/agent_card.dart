import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../listings/domain/property.dart';

class AgentCard extends StatelessWidget {
  const AgentCard({super.key, required this.agent, this.fallbackAgency});
  final Agent agent;
  final Agency? fallbackAgency;
  Future<void> _open(String value) async {
    final uri = Uri.parse(value);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final agency = agent.agency ?? fallbackAgency;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundImage: agent.photo?.isNotEmpty == true
                      ? CachedNetworkImageProvider(agent.photo!)
                      : null,
                  child: agent.photo?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              agent.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (agent.verified) ...[
                            const SizedBox(width: 5),
                            Icon(
                              Icons.verified_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      if (agency?.name.isNotEmpty == true)
                        Text(
                          agency!.name,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (agent.phone?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _open('tel:${agent.phone}'),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call'),
                  ),
                if (agent.whatsapp?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _open(
                      'https://wa.me/${agent.whatsapp!.replaceAll(RegExp(r'\D'), '')}',
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                if (agent.email?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _open('mailto:${agent.email}'),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
