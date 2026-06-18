import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/competition_providers.dart';

class StartMeetScreen extends ConsumerStatefulWidget {
  const StartMeetScreen({super.key});

  @override
  ConsumerState<StartMeetScreen> createState() => _StartMeetScreenState();
}

class _StartMeetScreenState extends ConsumerState<StartMeetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _federationCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bwCtrl = TextEditingController();
  final _wcCtrl = TextEditingController();
  final _divCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _federationCtrl.dispose();
    _locationCtrl.dispose();
    _bwCtrl.dispose();
    _wcCtrl.dispose();
    _divCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final comp = await ref.read(competitionListProvider.notifier).create(
            name: _nameCtrl.text.trim(),
            federation: _federationCtrl.text.trim().isEmpty
                ? null
                : _federationCtrl.text.trim(),
            date:
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            bodyweightKg: double.tryParse(_bwCtrl.text.trim()),
            weightClassKg: double.tryParse(_wcCtrl.text.trim()),
            division: _divCtrl.text.trim().isEmpty
                ? null
                : _divCtrl.text.trim(),
          );
      ref.read(activeMeetProvider.notifier).setMeet(comp);
      if (mounted) context.go(AppRoutes.meetDay);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to create meet. Please try again.')),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Meet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Meet Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            // Date picker
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _federationCtrl,
              decoration: const InputDecoration(
                labelText: 'Federation (e.g. IPF, USPA)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bwCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Bodyweight (kg)',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _wcCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight Class (kg)',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _divCtrl,
              decoration: const InputDecoration(
                labelText: 'Division (e.g. Open, Masters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start Meet'),
            ),
          ],
        ),
      ),
    );
  }
}
