import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import 'consumer_controller.dart';
import 'recent_screen.dart';
import 'social_auth.dart';

enum AccountMode { welcome, register, signIn, verify, forgot, reset }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AccountMode mode = AccountMode.welcome;
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();

  bool busy = false;
  String? error;
  String? message;
  String? profileOwner;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await action();
    } on ApiFailure catch (cause) {
      if (!mounted) return;
      final value = cause.message.toLowerCase();
      setState(() {
        error = value.contains('account_not_linked') ||
                value.contains('not linked')
            ? 'This email already belongs to a Homes account. Sign in with your existing method, then connect this provider from Security.'
            : cause.message;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'Unable to complete this request. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> social(ConsumerSocialProvider provider,
      {bool link = false}) async {
    final account = context.read<ConsumerController>();
    await perform(() async {
      await account.socialSignIn(provider, link: link);
      if (!mounted) return;
      setState(() => message =
          link ? 'Sign-in method connected.' : 'Welcome back to Homes.');
    });
  }

  Future<void> submit() async {
    if (form.currentState?.validate() != true) return;
    final account = context.read<ConsumerController>();
    await perform(() async {
      switch (mode) {
        case AccountMode.register:
          await account.auth('sign-up/email', {
            'name': name.text.trim(),
            'email': email.text.trim(),
            'phone': phone.text.trim(),
            'password': password.text,
          });
          if (mounted) {
            setState(() {
              mode = AccountMode.verify;
              password.clear();
              message =
                  'We sent a six-digit verification code. It expires in 10 minutes.';
            });
          }
        case AccountMode.signIn:
          await account.auth('sign-in/email', {
            'email': email.text.trim(),
            'password': password.text,
          });
          password.clear();
        case AccountMode.verify:
          await account.auth('email-otp/verify-email', {
            'email': email.text.trim(),
            'otp': code.text,
          });
          code.clear();
        case AccountMode.forgot:
          await account.auth('email-otp/request-password-reset', {
            'email': email.text.trim(),
          });
          if (mounted) {
            setState(() {
              mode = AccountMode.reset;
              message =
                  'If this email has a Homes account, a reset code is on its way.';
            });
          }
        case AccountMode.reset:
          await account.auth('email-otp/reset-password', {
            'email': email.text.trim(),
            'otp': code.text,
            'password': password.text,
          });
          if (mounted) {
            setState(() {
              mode = AccountMode.signIn;
              password.clear();
              code.clear();
              message = 'Password updated. Sign in with your new password.';
            });
          }
        case AccountMode.welcome:
          break;
      }
    });
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool secret = false,
    bool optional = false,
    TextInputType? keyboard,
    List<String>? autofill,
    int? min,
    int? max,
    String? hint,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          obscureText: secret,
          keyboardType: keyboard,
          autofillHints: autofill,
          maxLength: max,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
              labelText: label, hintText: hint, counterText: ''),
          validator: (value) {
            if (optional && (value?.trim().isEmpty ?? true)) return null;
            if ((value?.trim().length ?? 0) < (min ?? 1)) {
              return 'Enter ${label.toLowerCase()}${min != null ? ' ($min+ characters)' : ''}';
            }
            if (keyboard == TextInputType.emailAddress &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch(value!.trim())) {
              return 'Enter a valid email';
            }
            if (label == 'Six-digit code' &&
                !RegExp(r'^\d{6}$').hasMatch(value!)) {
              return 'Enter the six-digit code';
            }
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final account = context.watch<ConsumerController>();
    final user = account.user;

    if (user != null && profileOwner != user.id) {
      profileOwner = user.id;
      name.text = user.name;
      email.text = user.email;
      phone.text = user.phone;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Homes')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: account.loading
                ? const _AccountLoading()
                : !account.capabilitiesReachable
                    ? _Unavailable(
                        title: 'Account service is unavailable.',
                        body:
                            'Your local Saved and Compare selections are safe. You can keep browsing and try again later.',
                        onContinue: () => Navigator.maybePop(context),
                        onRetry: () => perform(account.refreshCapabilities),
                      )
                    : !account.accountsAvailable
                        ? _Unavailable(
                            title: 'Accounts are coming soon.',
                            body:
                                'You can still explore, save and compare homes on this device, and request viewings as a guest.',
                            onContinue: () => Navigator.maybePop(context),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 44),
                            children: [
                              if (user == null)
                                _SignedOutHeader(mode: mode)
                              else
                                _SignedInHeader(user: user),
                              if (error != null) ...[
                                const SizedBox(height: 14),
                                _Notice(error!, error: true),
                              ],
                              if (message != null) ...[
                                const SizedBox(height: 14),
                                _Notice(message!),
                              ],
                              if (account.feedback != null) ...[
                                const SizedBox(height: 14),
                                _Notice(account.feedback!),
                              ],
                              const SizedBox(height: 24),
                              if (user == null)
                                _signedOut(account)
                              else
                                _signedIn(account),
                            ],
                          ),
          ),
        ),
      ),
    );
  }

  Widget _signedOut(ConsumerController account) {
    if (mode == AccountMode.welcome) {
      final google =
          account.googleAvailable && AppConfig.googleWebClientId.isNotEmpty;
      final apple = account.appleAvailable &&
          (Theme.of(context).platform == TargetPlatform.iOS ||
              (AppConfig.appleServiceId.isNotEmpty &&
                  AppConfig.appleRedirectUri.isNotEmpty));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Benefits(),
          if (google) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed:
                  busy ? null : () => social(ConsumerSocialProvider.google),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.white
                        : null,
              ),
              child: const Text('Continue with Google'),
            ),
          ],
          if (apple) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: SignInWithAppleButton(
                onPressed:
                    busy ? null : () => social(ConsumerSocialProvider.apple),
                style: Theme.of(context).brightness == Brightness.dark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
                text: 'Continue with Apple',
              ),
            ),
          ],
          if (google || apple) const _OrDivider(),
          FilledButton(
            onPressed:
                busy ? null : () => setState(() => mode = AccountMode.register),
            child: const Text('Create account'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed:
                busy ? null : () => setState(() => mode = AccountMode.signIn),
            child: const Text('Sign in with email'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Continue as guest'),
          ),
        ],
      );
    }

    return AutofillGroup(
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mode == AccountMode.register) ...[
              field('Full name', name,
                  min: 2, max: 100, autofill: const [AutofillHints.name]),
              field('Phone (optional)', phone,
                  optional: true,
                  keyboard: TextInputType.phone,
                  max: 30,
                  hint: '+256…',
                  autofill: const [AutofillHints.telephoneNumber]),
            ],
            if ([AccountMode.register, AccountMode.signIn, AccountMode.forgot]
                .contains(mode))
              field('Email', email,
                  keyboard: TextInputType.emailAddress,
                  max: 254,
                  autofill: const [AutofillHints.email]),
            if ([AccountMode.register, AccountMode.signIn, AccountMode.reset]
                .contains(mode))
              field(
                mode == AccountMode.reset ? 'New password' : 'Password',
                password,
                secret: true,
                min: mode == AccountMode.signIn ? 1 : 12,
                max: 128,
                autofill: mode == AccountMode.signIn
                    ? const [AutofillHints.password]
                    : const [AutofillHints.newPassword],
              ),
            if ([AccountMode.verify, AccountMode.reset].contains(mode)) ...[
              Text(
                'Enter the six-digit code sent to ${email.text}. It expires in 10 minutes.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              field('Six-digit code', code,
                  min: 6,
                  max: 6,
                  keyboard: TextInputType.number,
                  autofill: const [AutofillHints.oneTimeCode]),
            ],
            if ([AccountMode.register, AccountMode.reset].contains(mode))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Use at least 12 characters. A memorable passphrase works well.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy
                    ? 'Please wait…'
                    : switch (mode) {
                        AccountMode.register => 'Create account',
                        AccountMode.signIn => 'Sign in',
                        AccountMode.verify => 'Verify email',
                        AccountMode.forgot => 'Send reset code',
                        AccountMode.reset => 'Update password',
                        _ => 'Continue',
                      },
              ),
            ),
            const SizedBox(height: 8),
            if (mode == AccountMode.signIn)
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => mode = AccountMode.forgot),
                child: const Text('Forgot password?'),
              ),
            if ([AccountMode.signIn, AccountMode.verify].contains(mode))
              TextButton(
                onPressed: busy
                    ? null
                    : () => perform(() async {
                          await account.auth(
                            'email-otp/send-verification-otp',
                            {
                              'email': email.text.trim(),
                              'type': 'email-verification',
                            },
                          );
                          if (mounted) {
                            setState(() {
                              mode = AccountMode.verify;
                              message =
                                  'If your account needs verification, a fresh code is on its way.';
                            });
                          }
                        }),
                child: const Text('Send verification code'),
              ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() => mode = mode == AccountMode.signIn
                      ? AccountMode.register
                      : AccountMode.signIn),
              child: Text(mode == AccountMode.signIn
                  ? 'Create account'
                  : 'Back to sign in'),
            ),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Continue as guest'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signedIn(ConsumerController account) {
    final user = account.user!;
    final providerIds =
        account.linkedAccounts.map((item) => item.providerId).toSet();
    final hasCredential = providerIds.contains('credential');
    final canGoogle = account.googleAvailable &&
        AppConfig.googleWebClientId.isNotEmpty &&
        !providerIds.contains('google');
    final canApple = account.appleAvailable &&
        !providerIds.contains('apple') &&
        (Theme.of(context).platform == TargetPlatform.iOS ||
            (AppConfig.appleServiceId.isNotEmpty &&
                AppConfig.appleRedirectUri.isNotEmpty));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountCard(
          eyebrow: 'Profile',
          title: 'Your details',
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field('Full name', name,
                    min: 2, max: 100, autofill: const [AutofillHints.name]),
                Text(
                  'Verified email · ${user.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                field('Phone', phone,
                    optional: true,
                    keyboard: TextInputType.phone,
                    max: 30,
                    hint: '+256…',
                    autofill: const [AutofillHints.telephoneNumber]),
                Text(
                  'Homes can reuse this contact information when you request a viewing.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => perform(() async {
                            if (form.currentState!.validate()) {
                              await account.updateProfile(
                                  name.text, phone.text);
                              if (mounted) {
                                setState(
                                    () => message = 'Contact details updated.');
                              }
                            }
                          }),
                  child: const Text('Save details'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _AccountCard(
          eyebrow: 'Security',
          title: 'Sign-in methods',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (account.linkedAccounts.isEmpty)
                Text(
                  'Your current sign-in method is secure. Connected methods will appear here.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final item in account.linkedAccounts)
                _LinkedMethod(
                  label: switch (item.providerId) {
                    'credential' => 'Email & password',
                    'google' => 'Google',
                    'apple' => 'Apple',
                    _ => item.providerId,
                  },
                  canDisconnect: item.providerId != 'credential' &&
                      account.linkedAccounts.length > 1,
                  onDisconnect: () => perform(() async {
                    await account.unlinkAccount(item.id);
                    if (mounted) {
                      setState(() => message = 'Sign-in method disconnected.');
                    }
                  }),
                ),
              if (canGoogle) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => social(ConsumerSocialProvider.google, link: true),
                  child: const Text('Connect Google'),
                ),
              ],
              if (canApple) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: SignInWithAppleButton(
                    onPressed: busy
                        ? null
                        : () =>
                            social(ConsumerSocialProvider.apple, link: true),
                    text: 'Connect Apple',
                    style: Theme.of(context).brightness == Brightness.dark
                        ? SignInWithAppleButtonStyle.white
                        : SignInWithAppleButtonStyle.black,
                  ),
                ),
              ],
              if (hasCredential) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PasswordChangeScreen()),
                  ),
                  child: const Text('Change password'),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => perform(() async {
                          await account.signOut();
                          profileOwner = null;
                          if (mounted) {
                            setState(() => mode = AccountMode.welcome);
                          }
                        }),
                child: const Text('Sign out'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => perform(() async {
                          await account.signOut(all: true);
                          profileOwner = null;
                          if (mounted) {
                            setState(() => mode = AccountMode.welcome);
                          }
                        }),
                child: const Text('Sign out all devices'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _AccountCard(
          eyebrow: 'Activity',
          title: 'Pick up where you left off',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecentHomesScreen(ids: account.recent),
                  ),
                ),
                child: const Text('Recently viewed'),
              ),
              const SizedBox(height: 8),
              Text(
                'Saved homes, Compare and viewing requests synchronize automatically while you are signed in.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _AccountCard(
          eyebrow: 'Data & account',
          title: 'Your control',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete your Homes account, synced selections and active sessions. Operational viewing records may remain only in anonymized form.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy
                    ? null
                    : () => _delete(account, hasCredential: hasCredential),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete account'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _delete(ConsumerController account,
      {required bool hasCredential}) async {
    final confirmation = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your profile, sessions and synced selections will be removed. This cannot be undone.',
            ),
            if (hasCredential) ...[
              const SizedBox(height: 16),
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm password'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'For a social-only account, Homes requires a recent authenticated session.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep account'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              hasCredential ? confirmation.text : '',
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    confirmation.dispose();
    if (result == null || !mounted) return;
    await perform(() async {
      await account.deleteAccount(result);
      profileOwner = null;
      if (mounted) {
        setState(() {
          mode = AccountMode.welcome;
          message = 'Account deleted.';
        });
      }
    });
  }
}

class _SignedOutHeader extends StatelessWidget {
  const _SignedOutHeader({required this.mode});
  final AccountMode mode;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR HOMES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.8,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Text(
            switch (mode) {
              AccountMode.welcome => 'Keep your place with you.',
              AccountMode.register => 'Create your Homes account.',
              AccountMode.signIn => 'Welcome back.',
              AccountMode.verify => 'Check your inbox.',
              AccountMode.forgot => 'Reset your password.',
              AccountMode.reset => 'Choose a new password.',
            },
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Browse without signing in. An account keeps your Saved homes, Compare shortlist, recent activity and viewing requests together across devices.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
}

class _SignedInHeader extends StatelessWidget {
  const _SignedInHeader({required this.user});
  final ConsumerProfile user;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR HOMES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.8,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Text(
            'Welcome, ${user.name.split(' ').first}.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Your Saved homes, comparisons and viewing requests stay with you across supported Homes devices.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          _Benefit(
            icon: Icons.favorite_border,
            title: 'Save once',
            body: 'See your favourites on web and mobile.',
          ),
          SizedBox(height: 10),
          _Benefit(
            icon: Icons.compare_arrows,
            title: 'Compare anywhere',
            body: 'Your shortlist stays in sync.',
          ),
          SizedBox(height: 10),
          _Benefit(
            icon: Icons.calendar_month_outlined,
            title: 'Manage viewings',
            body: 'Keep requests and statuses together.',
          ),
        ],
      );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 3),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard(
      {required this.eyebrow, required this.title, required this.child});
  final String eyebrow;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.4,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 5),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );
}

class _LinkedMethod extends StatelessWidget {
  const _LinkedMethod({
    required this.label,
    required this.canDisconnect,
    required this.onDisconnect,
  });
  final String label;
  final bool canDisconnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Connected',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (canDisconnect)
              TextButton(
                onPressed: onDisconnect,
                child: const Text('Disconnect'),
              ),
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: error
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color:
                  error ? Theme.of(context).colorScheme.onErrorContainer : null,
            ),
          ),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or use email',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
      );
}

class _AccountLoading extends StatelessWidget {
  const _AccountLoading();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 52, 22, 44),
        children: [
          Text('YOUR HOMES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.8,
                    color: Theme.of(context).colorScheme.primary,
                  )),
          const SizedBox(height: 10),
          Text('Getting things ready.',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          const Text('Restoring your account and saved homes securely.'),
          const SizedBox(height: 28),
          const LinearProgressIndicator(),
        ],
      );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.title,
    required this.body,
    required this.onContinue,
    this.onRetry,
  });
  final String title;
  final String body;
  final VoidCallback onContinue;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 52, 22, 44),
        children: [
          Text('YOUR HOMES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.8,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onContinue,
            child: const Text('Continue as guest'),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      );
}

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() => busy = true);
    try {
      await context.read<ConsumerController>().auth('change-password', {
        'currentPassword': current.text,
        'newPassword': next.text,
        'revokeOtherSessions': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed. Other devices are signed out.'),
          ),
        );
        Navigator.pop(context);
      }
    } on ApiFailure catch (cause) {
      if (mounted) setState(() => error = cause.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Change password')),
        body: SafeArea(
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Update your password',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Changing it will sign out your other Homes sessions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  _Notice(error!, error: true),
                ],
                const SizedBox(height: 22),
                TextFormField(
                  controller: current,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration:
                      const InputDecoration(labelText: 'Current password'),
                  validator: (value) => value?.isNotEmpty == true
                      ? null
                      : 'Enter your current password',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  maxLength: 128,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    counterText: '',
                  ),
                  validator: (value) => (value?.length ?? 0) >= 12
                      ? null
                      : 'Use at least 12 characters',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Please wait…' : 'Change password'),
                ),
              ],
            ),
          ),
        ),
      );
}
