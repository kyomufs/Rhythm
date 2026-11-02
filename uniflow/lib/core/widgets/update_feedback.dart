import 'package:flutter/material.dart';
import 'package:uniflow/core/services/update_coordinator.dart';

/// Показывает уведомление о результате обновления.
///
/// Офлайн не показывает ничего — это часть требования: «если не доступно то
/// ничего не происходит». Экран при этом остаётся как был, с сохранёнными
/// данными.
void showUpdateFeedback(BuildContext context, UpdateResult result) {
  if (!result.shouldNotify) return;
  final message = result.message;
  if (message == null || message.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            result.isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: Theme.of(context).colorScheme.onInverseSurface,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
