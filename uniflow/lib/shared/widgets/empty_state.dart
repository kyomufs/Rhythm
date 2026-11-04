import 'package:flutter/material.dart';
import 'package:uniflow/core/theme/spacing.dart';
import 'package:uniflow/core/theme/typography.dart';

/// Пустое состояние экрана: иконка, заголовок, пояснение и одно действие.
///
/// Раньше этот блок был скопирован в расписании и успеваемости с расхождениями
/// по отступам; теперь геометрия одна и живёт в шкале `AppSpacing`.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // M3E: иконка живёт в тональном «пятне», а не в пустоте —
            // экран без данных не выглядит сломанным.
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 52,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.emphasizedHeadlineSmall(
                theme.textTheme.headlineSmall!,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
