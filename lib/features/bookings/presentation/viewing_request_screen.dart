import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../listings/domain/property.dart';
import '../bookings_controller.dart';
import '../data/bookings_repository.dart';

class ViewingRequestScreen extends StatefulWidget {
  const ViewingRequestScreen({super.key, required this.property});
  final Property property;
  @override
  State<ViewingRequestScreen> createState() => _ViewingRequestScreenState();
}

class _ViewingRequestScreenState extends State<ViewingRequestScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      notes = TextEditingController();
  DateTime date =
      DateTime.now().add(const Duration(days: 1)).copyWith(hour: 10, minute: 0);
  bool submitting = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: date,
    );
    if (selected == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (time != null)
      setState(
        () => date = selected.copyWith(hour: time.hour, minute: time.minute),
      );
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => submitting = true);
    try {
      final request = await context.read<BookingsRepository>().requestViewing(
            ViewingRequestInput(
              propertyId: widget.property.id,
              guestName: name.text,
              guestEmail: email.text,
              guestPhone: phone.text,
              scheduledAt: date,
              notes: notes.text,
            ),
          );
      if (!mounted) return;
      await context.read<BookingsController>().add(request);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ViewingRequestConfirmation(
            property: widget.property,
            request: request,
          ),
        ),
      );
    } on ApiFailure catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.property.purpose == 'short_stay'
                ? 'Request availability'
                : 'Request a viewing',
          ),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatMoney(widget.property.price),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                            const SizedBox(height: 8),
                            Text(widget.property.title,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(widget.property.location.shortLabel,
                                style: Theme.of(context).textTheme.bodySmall),
                          ]))),
              const SizedBox(height: 24),
              Text('Preferred time · Uganda',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child:
                      Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(date)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Your details',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextFormField(
                controller: name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v?.contains('@') == true ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(labelText: 'Phone number'),
                validator: (v) =>
                    (v?.replaceAll(RegExp(r'\D'), '').length ?? 0) >= 9
                        ? null
                        : 'Enter a valid phone number',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notes,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Share any timing or access details',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'This is a request. The property representative must confirm the time before your viewing is scheduled.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit viewing request'),
              ),
            ],
          ),
        ),
      );
}

class ViewingRequestConfirmation extends StatelessWidget {
  const ViewingRequestConfirmation({
    super.key,
    required this.property,
    required this.request,
  });
  final Property property;
  final ViewingRequest request;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Request received',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                'Your request is pending until the property representative confirms it.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(height: 28),
                      _row('Reference', request.reference),
                      _row(
                        'Requested time',
                        DateFormat(
                          'EEE, d MMM yyyy · h:mm a',
                        ).format(request.scheduledAt.toLocal()),
                      ),
                      _row('Status', titleCase(request.status)),
                      _row('Name', request.guestName),
                      _row('Email', request.guestEmail),
                      _row('Phone', request.guestPhone),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Return to Homes'),
              ),
            ],
          ),
        ),
      );
  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
