import 'package:flutter/material.dart';
import '../models/project_task.dart';

class CompletionDialog extends StatefulWidget {
  final ProjectTask task;
  const CompletionDialog({super.key, required this.task});

  @override
  State<CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<CompletionDialog> {
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
    final est = widget.task.estimatedHours;
    if (est > 0) {
      final hours = est.toInt();
      final minutes = ((est - hours) * 60).round();
      _hoursController.text = hours.toString();
      _minutesController.text = minutes > 0 ? minutes.toString() : '0';
    } else {
      _hoursController.text = '0';
      _minutesController.text = '0';
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = '${_selectedDateTime.day.toString().padLeft(2, '0')}.'
        '${_selectedDateTime.month.toString().padLeft(2, '0')}.'
        '${_selectedDateTime.year} '
        '${_selectedDateTime.hour.toString().padLeft(2, '0')}:'
        '${_selectedDateTime.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
          const SizedBox(width: 10),
          const Text('Kończenie zadania'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Wprowadź czas poświęcony na zadanie oraz faktyczną datę zakończenia.',
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
              const SizedBox(height: 20),
              
              Text(
                'Data zakończenia:',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDateTime,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
              final double actualHours = h + (m / 60.0);
              
              Navigator.of(context).pop({
                'actualHours': actualHours,
                'completedAt': _selectedDateTime,
              });
            }
          },
          child: Text(
            'Zakończ', 
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
