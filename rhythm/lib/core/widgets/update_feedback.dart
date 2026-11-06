import 'package:flutter/material.dart';
import 'package:rhythm/core/services/update_coordinator.dart';
import 'package:rhythm/core/widgets/app_notice.dart';

/// Показывает уведомление о результате обновления.
///
/// Офлайн не показывает ничего — это часть требования: «если не доступно то
/// ничего не происходит». Экран при этом остаётся как был, с сохранёнными
/// данными.
///
/// Всплывающая плашка, а не полоса у нижней кромки: она не наезжает на нижнее
/// меню и явно говорит, что данные обновились.
void showUpdateFeedback(BuildContext context, UpdateResult result) {
  if (!result.shouldNotify) return;
  final message = result.message;
  if (message == null || message.isEmpty) return;
  _showUpdateNotice(context, message, isSuccess: result.isSuccess);
}

/// Уведомление об успешном обновлении по набору обновлённых данных.
///
/// Один вход для всех путей: кнопка обновления, жест вниз и автообновление
/// при входе в приложение. Текст выбирается по тому, что реально обновилось.
void showUpdateSuccessNotification(
  BuildContext context, {
  required bool schedule,
  required bool marks,
}) {
  if (!schedule && !marks) return;
  _showUpdateNotice(
    context,
    updateSuccessText(schedule: schedule, marks: marks),
    isSuccess: true,
  );
}

void _showUpdateNotice(
  BuildContext context,
  String message, {
  required bool isSuccess,
}) {
  AppNotice.show(
    context,
    message: message,
    tone: isSuccess ? AppNoticeTone.success : AppNoticeTone.error,
  );
}
