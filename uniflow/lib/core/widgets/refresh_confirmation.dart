import 'package:flutter/material.dart';

/// Подтверждение обновления данных.
///
/// Кнопка «обновить» и жест вниз — это намерение, а не команда: запрос уходит
/// только после явного согласия. Копирайт один на расписание и успеваемость,
/// чтобы диалоги не разъезжались.
Future<bool> confirmRefresh(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.refresh),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Обновить',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
