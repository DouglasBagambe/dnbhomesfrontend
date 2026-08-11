import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/theme_controller.dart';
import 'simple_content_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const _Header('Preferences'),
          ListTile(
            leading: const Icon(Icons.contrast),
            title: const Text('Theme'),
            subtitle: Text(switch (theme.mode) {
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
              _ => 'Use device setting',
            }),
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) => SafeArea(
                child: RadioGroup<ThemeMode>(
                  groupValue: theme.mode,
                  onChanged: (value) {
                    if (value != null) theme.setMode(value);
                    Navigator.pop(context);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ThemeMode.values
                        .map(
                          (mode) => RadioListTile<ThemeMode>(
                            value: mode,
                            title: Text(switch (mode) {
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                              _ => 'Use device setting',
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          const _Header('Support'),
          _link(context, Icons.help_outline, 'Help', ContentType.help),
          _link(
            context,
            Icons.shield_outlined,
            'Safety tips',
            ContentType.safety,
          ),
          _link(context, Icons.mail_outline, 'Contact', ContentType.contact),
          const _Header('Legal'),
          _link(
            context,
            Icons.privacy_tip_outlined,
            'Privacy policy',
            ContentType.privacy,
          ),
          _link(
            context,
            Icons.description_outlined,
            'Terms of service',
            ContentType.terms,
          ),
          const _Header('About'),
          _link(context, Icons.info_outline, 'About Homes', ContentType.about),
          const ListTile(
            leading: Icon(Icons.tag),
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _link(
    BuildContext context,
    IconData icon,
    String label,
    ContentType type,
  ) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SimpleContentScreen(type: type)),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}
