import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import 'consumer_controller.dart';
import 'recent_screen.dart';

enum AccountMode { welcome, register, signIn, verify, forgot, reset }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AccountMode mode = AccountMode.welcome;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool busy = false;
  String? error, message;
  String? profileOwner;
  @override
  void dispose() {
    for (final controller in [name, email, phone, password, code]) {
      controller.dispose();
    }
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
      if (mounted) setState(() => error = cause.message);
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'Unable to complete this request. Please retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
            'password': password.text
          });
          if (mounted)
            setState(() {
              mode = AccountMode.verify;
              password.clear();
              message = 'Check your inbox for your six-digit Homes code.';
            });
        case AccountMode.signIn:
          await account.auth('sign-in/email',
              {'email': email.text.trim(), 'password': password.text});
          password.clear();
        case AccountMode.verify:
          await account.auth('email-otp/verify-email',
              {'email': email.text.trim(), 'otp': code.text});
          code.clear();
        case AccountMode.forgot:
          await account.auth(
              'email-otp/request-password-reset', {'email': email.text.trim()});
          if (mounted)
            setState(() {
              mode = AccountMode.reset;
              message =
                  'If your email has an account, a reset code is on its way.';
            });
        case AccountMode.reset:
          await account.auth('email-otp/reset-password', {
            'email': email.text.trim(),
            'otp': code.text,
            'password': password.text
          });
          if (mounted)
            setState(() {
              mode = AccountMode.signIn;
              password.clear();
              code.clear();
              message = 'Password updated. Sign in with your new password.';
            });
        case AccountMode.welcome:
          break;
      }
    });
  }

  Widget field(String label, TextEditingController controller,
          {bool secret = false,
          bool optional = false,
          TextInputType? keyboard,
          List<String>? autofill,
          int? min,
          int? max}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: controller,
              obscureText: secret,
              keyboardType: keyboard,
              autofillHints: autofill,
              maxLength: max,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: label, counterText: ''),
              validator: (value) {
                if (optional && (value?.isEmpty ?? true)) return null;
                if ((value?.trim().length ?? 0) < (min ?? 1))
                  return 'Enter ${label.toLowerCase()}${min != null ? ' ($min+ characters)' : ''}';
                if (keyboard == TextInputType.emailAddress &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!))
                  return 'Enter a valid email';
                if (label == 'Six-digit code' &&
                    !RegExp(r'^\d{6}$').hasMatch(value!))
                  return 'Enter the six-digit code';
                return null;
              }));
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
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        children: [
                          if (account.loading) const LinearProgressIndicator(),
                          Text(
                              user == null
                                  ? switch (mode) {
                                      AccountMode.welcome => 'Welcome to Homes',
                                      AccountMode.register =>
                                        'Make yourself at home',
                                      AccountMode.signIn => 'Welcome back',
                                      AccountMode.verify => 'Check your inbox',
                                      AccountMode.forgot =>
                                        'Reset your password',
                                      AccountMode.reset =>
                                        'Choose a new password'
                                    }
                                  : 'Welcome, ${user.name.split(' ').first}',
                              style: Theme.of(context).textTheme.headlineLarge),
                          const SizedBox(height: 12),
                          Text(
                              user == null
                                  ? 'Explore freely. Your account keeps Saved homes and viewings together across your devices.'
                                  : 'Your Saved homes and viewing requests follow you across devices.',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 24),
                          if (error != null)
                            Semantics(
                                liveRegion: true,
                                child: Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          if (message != null)
                            Semantics(liveRegion: true, child: Text(message!)),
                          if (account.feedback != null) Text(account.feedback!),
                          if (user != null) ...[
                            Form(
                                key: form,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      field('Full name', name,
                                          min: 2,
                                          max: 100,
                                          autofill: const [AutofillHints.name]),
                                      Text('Verified email · ${user.email}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium),
                                      const SizedBox(height: 20),
                                      field('Phone', phone,
                                          optional: true,
                                          keyboard: TextInputType.phone,
                                          max: 30,
                                          autofill: const [
                                            AutofillHints.telephoneNumber
                                          ]),
                                      FilledButton(
                                          onPressed: busy
                                              ? null
                                              : () => perform(() async {
                                                    if (form.currentState!
                                                        .validate()) {
                                                      await account
                                                          .updateProfile(
                                                              name.text,
                                                              phone.text);
                                                      if (mounted)
                                                        setState(() => message =
                                                            'Contact details updated.');
                                                    }
                                                  }),
                                          child: const Text('Save details')),
                                    ])),
                            const SizedBox(height: 24),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Viewing updates'),
                                subtitle: const Text(
                                    'Live statuses always remain available in Viewings.'),
                                value: account.viewingUpdates,
                                onChanged: busy
                                    ? null
                                    : (value) => perform(() async {
                                          await account.api.postJson(
                                              '/consumer/preferences', {
                                            'viewingUpdates': value,
                                            'searchAlerts': false
                                          });
                                          await account.refresh();
                                        })),
                            const Text(
                                'Property email alerts are coming later.'),
                            const SizedBox(height: 24),
                            OutlinedButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => RecentHomesScreen(
                                            ids: account.recent))),
                                child: const Text('Recently viewed')),
                            OutlinedButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PasswordChangeScreen())),
                                child: const Text('Change password')),
                            OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => perform(account.refresh),
                                child: Text(account.syncing
                                    ? 'Syncing…'
                                    : 'Refresh account sync')),
                            OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => perform(() async {
                                          await account.signOut();
                                          profileOwner = null;
                                          if (mounted)
                                            setState(() =>
                                                mode = AccountMode.welcome);
                                        }),
                                child: const Text('Sign out')),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => perform(() async {
                                          await account.signOut(all: true);
                                          profileOwner = null;
                                          if (mounted)
                                            setState(() =>
                                                mode = AccountMode.welcome);
                                        }),
                                child: const Text('Sign out all devices')),
                            TextButton(
                                onPressed: busy ? null : () => _delete(account),
                                child: const Text('Delete account')),
                          ] else if (mode == AccountMode.welcome) ...[
                            OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Continue as guest')),
                            FilledButton(
                                onPressed: () =>
                                    setState(() => mode = AccountMode.register),
                                child: const Text('Create account')),
                            TextButton(
                                onPressed: () =>
                                    setState(() => mode = AccountMode.signIn),
                                child: const Text('Sign in')),
                          ] else ...[
                            AutofillGroup(
                                child: Form(
                                    key: form,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (mode == AccountMode.register) ...[
                                            field('Full name', name,
                                                min: 2,
                                                max: 100,
                                                autofill: const [
                                                  AutofillHints.name
                                                ]),
                                            field('Phone (optional)', phone,
                                                optional: true,
                                                keyboard: TextInputType.phone,
                                                max: 30,
                                                autofill: const [
                                                  AutofillHints.telephoneNumber
                                                ])
                                          ],
                                          field('Email', email,
                                              keyboard:
                                                  TextInputType.emailAddress,
                                              max: 254,
                                              autofill: const [
                                                AutofillHints.email
                                              ]),
                                          if ([
                                            AccountMode.register,
                                            AccountMode.signIn,
                                            AccountMode.reset
                                          ].contains(mode))
                                            field('Password', password,
                                                secret: true,
                                                min: mode == AccountMode.signIn
                                                    ? 1
                                                    : 12,
                                                max: 128,
                                                autofill: mode ==
                                                        AccountMode.signIn
                                                    ? const [
                                                        AutofillHints.password
                                                      ]
                                                    : const [
                                                        AutofillHints
                                                            .newPassword
                                                      ]),
                                          if ([
                                            AccountMode.verify,
                                            AccountMode.reset
                                          ].contains(mode))
                                            field('Six-digit code', code,
                                                min: 6,
                                                max: 6,
                                                keyboard: TextInputType.number,
                                                autofill: const [
                                                  AutofillHints.oneTimeCode
                                                ]),
                                          if ([
                                            AccountMode.register,
                                            AccountMode.reset
                                          ].contains(mode))
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(bottom: 16),
                                                child: Text(
                                                    'Use at least 12 characters. A memorable passphrase works well.')),
                                          FilledButton(
                                              onPressed: busy ? null : submit,
                                              child: Text(busy
                                                  ? 'Please wait…'
                                                  : switch (mode) {
                                                      AccountMode.register =>
                                                        'Create account',
                                                      AccountMode.signIn =>
                                                        'Sign in',
                                                      AccountMode.verify =>
                                                        'Verify email',
                                                      AccountMode.forgot =>
                                                        'Send reset code',
                                                      AccountMode.reset =>
                                                        'Update password',
                                                      _ => 'Continue'
                                                    })),
                                        ]))),
                            if (mode == AccountMode.signIn)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => mode = AccountMode.forgot),
                                  child: const Text('Forgot password?')),
                            if ([AccountMode.signIn, AccountMode.verify]
                                .contains(mode))
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => perform(() async {
                                            await account.auth(
                                                'email-otp/send-verification-otp',
                                                {
                                                  'email': email.text.trim(),
                                                  'type': 'email-verification'
                                                });
                                            if (mounted)
                                              setState(() {
                                                mode = AccountMode.verify;
                                                message =
                                                    'If your account needs verification, a code is on its way.';
                                              });
                                          }),
                                  child: const Text('Send verification code')),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() => mode =
                                        mode == AccountMode.signIn
                                            ? AccountMode.register
                                            : AccountMode.signIn),
                                child: Text(mode == AccountMode.signIn
                                    ? 'Create account'
                                    : 'Back to sign in')),
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Continue as guest')),
                          ],
                        ])))));
  }

  Future<void> _delete(ConsumerController account) async {
    final confirmation = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete your account?'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Your profile and selections will be removed. Viewing records are retained without account contact details.'),
                  const SizedBox(height: 16),
                  TextField(
                      controller: confirmation,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep account')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, confirmation.text),
                      child: const Text('Delete account'))
                ]));
    // Dialog field is disposed after its closing transition, not while still mounted.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    confirmation.dispose();
    if (result == null || !mounted) return;
    await perform(() async {
      await account.deleteAccount(result);
      profileOwner = null;
      if (mounted)
        setState(() {
          mode = AccountMode.welcome;
          message = 'Account deleted.';
        });
    });
  }
}

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});
  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(), next = TextEditingController();
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
        'revokeOtherSessions': true
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Password changed. Other devices are signed out.')));
        Navigator.pop(context);
      }
    } on ApiFailure catch (cause) {
      if (mounted) setState(() => error = cause.message);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Unable to change password. Please retry.');
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
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                TextFormField(
                    controller: current,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration:
                        const InputDecoration(labelText: 'Current password'),
                    validator: (value) => value?.isNotEmpty == true
                        ? null
                        : 'Enter your current password'),
                const SizedBox(height: 20),
                TextFormField(
                    controller: next,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    maxLength: 128,
                    decoration: const InputDecoration(
                        labelText: 'New password', counterText: ''),
                    validator: (value) => (value?.length ?? 0) >= 12
                        ? null
                        : 'Use at least 12 characters'),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'Please wait…' : 'Change password')),
              ]))));
}
