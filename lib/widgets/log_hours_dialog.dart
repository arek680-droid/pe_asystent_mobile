import 'package:flutter/material.dart';
import '../models/project_task.dart';

class LogHoursDialog extends StatefulWidget {
  final ProjectTask task;
  const LogHoursDialog({super.key, required this.task});

  @override
  State<LogHoursDialog> createState() => _LogHoursDialogState();
}

class _LogHoursDialogState extends State<LogHoursDialog> {
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '0');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.more_time_rounded, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 10),
          const Text('Dodaj czas pracy'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Wpisz czas poświęcony na to zadanie dzisiaj. Zadanie pozostanie w trakcie realizacji.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Godziny',
                      border: OutlineInputBorder(),
                      suffixText: 'h',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Wymagane';
                      final h = int.tryParse(value);
                      if (h == null || h < 0) return 'Niepoprawna';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    decoration: const InputDecoration(
                      labelText: 'Minuty',
                      border: OutlineInputBorder(),
                      suffixText: 'm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Wymagane';
                      final m = int.tryParse(value);
                      if (m == null || m < 0 || m > 59) return '0-59';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Anuluj', style: TextStyle(color: theme.colorScheme.secondary)),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final h = int.parse(_hoursController.text);
              final m = int.parse(_minutesController.text);
              final double hours = h + (m / 60.0);
              
              if (hours <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Czas pracy musi być większy niż 0')),
                );
                return;
              }
              Navigator.of(context).pop(hours);
            }
          },
          child: Text(
            'Dodaj', 
            style: TextStyle(
              color: theme.colorScheme.primary, 
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
