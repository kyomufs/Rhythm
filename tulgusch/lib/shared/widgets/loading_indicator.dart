import 'package:flutter/material.dart';
import 'package:tulgusch/core/theme/spacing.dart';
import 'package:tulgusch/shared/widgets/expressive_loading_indicator.dart';

/// Loading indicator widget
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final bool isFullScreen;

  const LoadingIndicator({
    super.key,
    this.message,
    this.isFullScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // M3E: морфящаяся фигура вместо вращающейся дуги.
        const ExpressiveLoadingIndicator(size: 48),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (isFullScreen) {
      return Center(child: content);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(child: content),
    );
  }
}

/// Inline loading indicator
class InlineLoadingIndicator extends StatelessWidget {
  final String? message;

  const InlineLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ExpressiveLoadingIndicator(size: 24),
          if (message != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
