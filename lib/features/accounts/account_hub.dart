import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bookings/presentation/bookings_screen.dart';
import '../compare/presentation/compare_screen.dart';
import '../settings/presentation/settings_screen.dart';
import 'account_screen.dart';
import 'consumer_controller.dart';
import 'recent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountHub extends StatelessWidget {
  const AccountHub({super.key});
  @override
  Widget build(BuildContext context) {
    final account = context.watch<ConsumerController>();
    void open(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    Widget row(
            IconData icon, String title, String subtitle, VoidCallback onTap) =>
        ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap);
    return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 36),
                            const SizedBox(height: 16),
                            Text(
                                account.signedIn
                                    ? 'Your Homes account'
                                    : 'Your next chapter starts here.',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(account.signedIn
                                ? 'Manage your profile and account security.'
                                : 'Explore, save and request viewings as a guest. Sign in when you’re ready to sync across devices.'),
                            const SizedBox(height: 18),
                            FilledButton(
                                onPressed: () => open(const AccountScreen()),
                                child: Text(account.signedIn
                                    ? 'Manage account'
                                    : 'Sign in or create account')),
                          ]))),
              const SizedBox(height: 22),
              Text('Your property journey',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Card(
                  child: Column(children: [
                row(
                    Icons.calendar_month_outlined,
                    'Viewings',
                    'Requests, appointments and updates',
                    () => open(const BookingsScreen())),
                const Divider(height: 1),
                row(Icons.history, 'Recently viewed',
                    'Pick up where you left off', () async {
                  final ids = account.signedIn
                      ? account.recent
                      : (await SharedPreferences.getInstance())
                              .getStringList('homes_guest_recent') ??
                          <String>[];
                  if (context.mounted) open(RecentHomesScreen(ids: ids));
                }),
                const Divider(height: 1),
                row(
                    Icons.balance_outlined,
                    'Compare homes',
                    'Review your shortlist side by side',
                    () => open(const CompareScreen())),
              ])),
              const SizedBox(height: 22),
              row(
                  Icons.tune,
                  'Settings & support',
                  'Appearance, help, safety and legal information',
                  () => open(const SettingsScreen())),
            ]));
  }
}
