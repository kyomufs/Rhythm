import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uniflow/core/domain/journal.dart';
import 'package:uniflow/core/domain/source.dart';
import 'package:uniflow/core/input/desktop_input.dart';
import 'package:uniflow/core/journal/journal_store.dart';
import 'package:uniflow/core/services/schedule_service.dart';
import 'package:uniflow/core/services/storage_service.dart';
import 'package:uniflow/core/sources/source_store.dart';
import 'package:uniflow/core/theme/shapes.dart';
import 'package:uniflow/core/theme/spacing.dart';
import 'package:uniflow/core/theme/typography.dart';
import 'package:uniflow/features/journal/screens/course_screen.dart';
import 'package:uniflow/features/journal/widgets/course_style.dart';
import 'package:uniflow/features/journal/widgets/journal_editors.dart';
import 'package:uniflow/features/schedule/providers/schedule_provider.dart';
import 'package:uniflow/features/sources/screens/source_edit_screen.dart';
import 'package:uniflow/features/sources/widgets/source_pill.dart';
import 'package:uniflow/shared/widgets/empty_state.dart';
import 'package:uniflow/shared/widgets/morph_chip.dart';
import 'package:uniflow/shared/widgets/wavy_progress.dart';

/// Журнал успеваемости: лента семестров, сводка и дисциплины.
///
/// Всё, что можно завести автоматически, заводится из расписания одной
/// кнопкой; всё, что автоматика угадала неверно, правится и удаляется руками
/// на этом же экране.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

enum _JournalAction { import, newTerm, editTerm, deleteTerm }

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _termController = ScrollController();
  String? _termId;
  bool _importing = false;

  @override
  void dispose() {
    _termController.dispose();
    super.dispose();
  }

  Term _draftTerm(Source source) => Term(
        id: '_draft',
        sourceId: source.id,
        title: 'Текущий семестр',
        start: DateTime.now(),
        end: DateTime.now(),
      );

  Future<void> _newTerm(Source source) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TermEditorDialog(sourceId: source.id),
    );
    final terms = ref.read(journalProvider).data.terms;
    if (terms.isNotEmpty) {
      setState(() => _termId = terms.last.id);
    }
  }

  Future<void> _editTerm(Term term) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TermEditorDialog(sourceId: term.sourceId, term: term),
    );
  }

  Future<void> _deleteTerm(Term term) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить семестр?',
      message: 'Вместе с «${term.title}» удалятся его дисциплины, пары '
          'и события. Это необратимо.',
    );
    if (!confirmed || !mounted) return;
    ref.read(journalProvider.notifier).deleteTerm(term.id);
    setState(() => _termId = null);
  }

  Future<void> _addCourse(Term term) async {
    await showDialog<void>(
      context: context,
      builder: (_) => CourseEditorDialog(term: term),
    );
  }

  /// Импорт расписания. Сначала берём уже загруженное на вкладке
  /// «Расписание», и только если его нет — идём в сеть за своей группой.
  Future<void> _import(Source source) async {
    if (_importing) return;
    if (source.isManual) {
      _snack('У источника «${source.title}» нет расписания — дисциплины '
          'добавляются вручную');
      return;
    }
    setState(() => _importing = true);
    try {
      var items = ref.read(scheduleScreenProvider).schedule.items;
      if (items.isEmpty) {
        final group = ref.read(storageServiceProvider).getFullAcademicGroup();
        if (group != null) {
          final state =
              await ref.read(scheduleServiceProvider).getSchedule(group);
          items = state.items;
        }
      }
      if (!mounted) return;
      if (items.isEmpty) {
        _snack('Расписание пустое — обновите его на вкладке «Расписание»');
        return;
      }
      final result = ref.read(journalProvider.notifier).importSchedule(items);
      final terms = ref.read(journalProvider).data.terms;
      if (terms.isNotEmpty) setState(() => _termId = terms.last.id);
      _snack(result.courses == 0 && result.lessons == 0
          ? 'Всё из расписания уже в журнале'
          : 'Добавлено пар: ${result.lessons} · '
              'дисциплин: ${result.courses}');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(activeSourceProvider);
    final journal = ref.watch(journalProvider);

    if (source == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Журнал')),
        body: EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Нет источника',
          message: 'Добавьте университет, школу или работу —\n'
              'журнал ведётся отдельно для каждого',
          action: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SourceEditScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Добавить источник'),
          ),
        ),
      );
    }

    final terms = journal.data.terms;
    final term = _termId == null
        ? (terms.isEmpty ? null : terms.last)
        : terms.firstWhere(
            (t) => t.id == _termId,
            orElse: () => terms.isEmpty ? _draftTerm(source) : terms.last,
          );
    final courses =
        term == null ? const <Course>[] : journal.data.coursesOf(term.id);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: const SourcePill(maxWidth: 130),
        actions: [
          PopupMenuButton<_JournalAction>(
            tooltip: 'Журнал',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _JournalAction.import:
                  _import(source);
                case _JournalAction.newTerm:
                  _newTerm(source);
                case _JournalAction.editTerm:
                  if (term != null) _editTerm(term);
                case _JournalAction.deleteTerm:
                  if (term != null) _deleteTerm(term);
              }
            },
            itemBuilder: (_) => [
              if (!source.isManual)
                const PopupMenuItem(
                  value: _JournalAction.import,
                  child: _MenuRow(
                    icon: Icons.sync,
                    label: 'Заполнить из расписания',
                  ),
                ),
              const PopupMenuItem(
                value: _JournalAction.newTerm,
                child: _MenuRow(icon: Icons.event_repeat, label: 'Новый семестр'),
              ),
              if (term != null) ...[
                const PopupMenuItem(
                  value: _JournalAction.editTerm,
                  child: _MenuRow(icon: Icons.edit_calendar, label: 'Семестр'),
                ),
                const PopupMenuItem(
                  value: _JournalAction.deleteTerm,
                  child: _MenuRow(icon: Icons.delete_outline, label: 'Удалить семестр'),
                ),
              ],
            ],
          ),
        ],
      ),
      floatingActionButton: term == null || courses.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addCourse(term),
              icon: const Icon(Icons.add),
              label: const Text('Дисциплина'),
            ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Журнал',
                    style: AppTypography.emphasizedHeadlineMedium(
                      Theme.of(context).textTheme.headlineMedium!,
                    ),
                  ),
                  const Gap(AppSpacing.xxs),
                  Text(
                    'Баллы, посещение и события по каждому предмету',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (terms.isNotEmpty)
            SliverToBoxAdapter(
              child: _TermStrip(
                terms: terms,
                selectedId: term?.id,
                controller: _termController,
                onSelected: (id) => setState(() => _termId = id),
              ),
            ),
          if (term != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              sliver: SliverToBoxAdapter(
                child: _TermHero(
                  term: term,
                  courses: courses,
                  importing: _importing,
                  canImport: !source.isManual,
                  onImport: () => _import(source),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Дисциплины',
                trailing: courses.isEmpty ? null : '${courses.length}',
              ),
            ),
          ),
          if (term == null || courses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: term == null
                      ? 'Журнал ещё пуст'
                      : 'В семестре нет дисциплин',
                  message: source.isManual
                      ? 'Добавьте предмет и настройте шкалу —\n'
                          'баллы и посещение отмечаются вручную'
                      : 'Заполните журнал из расписания или добавьте\n'
                          'предмет вручную — данные можно править',
                  action: Column(
                    children: [
                      if (!source.isManual)
                        FilledButton.icon(
                          onPressed: _importing ? null : () => _import(source),
                          icon: _importing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync),
                          label: const Text('Заполнить из расписания'),
                        ),
                      if (!source.isManual) const Gap(AppSpacing.xs),
                      TextButton.icon(
                        onPressed: term == null
                            ? () => _newTerm(source)
                            : () => _addCourse(term),
                        icon: Icon(
                            term == null ? Icons.event_repeat : Icons.add),
                        label: Text(term == null
                            ? 'Начать семестр'
                            : 'Добавить дисциплину'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, 96),
              sliver: SliverList.separated(
                itemCount: courses.length,
                separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
                itemBuilder: (context, index) => _CourseCard(
                  course: courses[index],
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CourseScreen(courseId: courses[index].id),
                    ),
                  ),
                  onEdit: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        CourseEditorDialog(term: term, course: courses[index]),
                  ),
                  onDelete: () => _deleteCourse(courses[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteCourse(Course course) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить дисциплину?',
      message: '«${course.title}» вместе с парами, событиями и баллами '
          'исчезнет из журнала.',
    );
    if (!confirmed || !mounted) return;
    ref.read(journalProvider.notifier).deleteCourse(course.id);
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const Gap(AppSpacing.sm),
        Text(label),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.emphasizedTitleMedium(theme.textTheme.titleMedium!),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _TermStrip extends StatelessWidget {
  const _TermStrip({
    required this.terms,
    required this.selectedId,
    required this.controller,
    required this.onSelected,
  });

  final List<Term> terms;
  final String? selectedId;
  final ScrollController controller;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: WheelScroll(
        controller: controller,
        child: DragPan(
          controller: controller,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: terms.length,
            separatorBuilder: (_, __) => const Gap(2),
            itemBuilder: (context, index) {
              final term = terms[index];
              return Center(
                child: MorphChip(
                  label: term.title,
                  selected: term.id == selectedId,
                  isFirst: index == 0,
                  isLast: index == terms.length - 1,
                  onTap: () => onSelected(term.id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Сводка семестра: средний процент, объём и вход в импорт.
class _TermHero extends ConsumerWidget {
  const _TermHero({
    required this.term,
    required this.courses,
    required this.importing,
    required this.canImport,
    required this.onImport,
  });

  final Term term;
  final List<Course> courses;
  final bool importing;
  final bool canImport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('d MMM', 'ru');

    var earned = 0.0;
    var max = 0.0;
    var lessons = 0;
    var visited = 0;
    for (final course in courses) {
      final stats = ref.watch(courseStatsProvider(course.id));
      earned += stats.total;
      max += stats.totalMax;
      lessons += stats.lessons;
      visited += stats.visited;
    }
    final percent = max == 0 ? 0.0 : (earned / max).clamp(0.0, 1.0);
    final attendance = lessons == 0 ? 0 : (visited * 100 / lessons).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppShapes.extraLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_outlined,
                  size: 16, color: scheme.onPrimaryContainer),
              const Gap(AppSpacing.xxs),
              Text(
                '${df.format(term.start)} — ${df.format(term.end)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                courses.length == 1
                    ? '1 дисциплина'
                    : '${courses.length} дисциплин',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(percent * 100).round()}',
                style: AppTypography.emphasizedHeadlineLarge(
                  theme.textTheme.headlineLarge!,
                ).copyWith(color: scheme.onPrimaryContainer, height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  '%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_num(earned)} / ${_num(max)}',
                    style: AppTypography.emphasizedTitleMedium(
                      theme.textTheme.titleMedium!,
                    ).copyWith(color: scheme.onPrimaryContainer),
                  ),
                  Text(
                    'баллов в семестре',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          WavyProgressIndicator(
            value: percent,
            color: scheme.onPrimaryContainer,
            trackColor: scheme.onPrimaryContainer.withValues(alpha: 0.22),
          ),
          const Gap(AppSpacing.sm),
          Row(
            children: [
              _HeroMetric(
                icon: Icons.fact_check_outlined,
                value: '$lessons',
                label: 'пар',
              ),
              const Gap(AppSpacing.md),
              _HeroMetric(
                icon: Icons.how_to_reg,
                value: '$attendance%',
                label: 'посещение',
              ),
              const Spacer(),
              if (canImport)
                TextButton.icon(
                  onPressed: importing ? null : onImport,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimaryContainer,
                    backgroundColor:
                        scheme.onPrimaryContainer.withValues(alpha: 0.10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: importing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimaryContainer,
                          ),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: const Text('Из расписания'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
        const Gap(AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.emphasizedLabelLarge(
            theme.textTheme.labelLarge!,
          ).copyWith(color: color),
        ),
        const Gap(2),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({
    required this.course,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = ref.watch(courseStatsProvider(course.id));
    final passed = stats.total >= stats.scale.passThreshold;
    final accent = courseAccent(scheme, course.colorIndex);

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius:
                          BorderRadius.circular(AppShapes.medium),
                    ),
                    child: Icon(Icons.menu_book_outlined, color: accent),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.emphasizedTitleMedium(
                            theme.textTheme.titleMedium!,
                          ),
                        ),
                        if (course.teacher != null &&
                            course.teacher!.isNotEmpty) ...[
                          const Gap(2),
                          Text(
                            course.teacher!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Дисциплина',
                    icon: Icon(Icons.more_vert,
                        size: 20, color: scheme.onSurfaceVariant),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Изменить')),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                ],
              ),
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: WavyProgressIndicator(
                      value: stats.percent.clamp(0.0, 1.0),
                      color: accent,
                      trackColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    '${_num(stats.total)} / ${_num(stats.totalMax)}',
                    style: AppTypography.emphasizedLabelLarge(
                      theme.textTheme.labelLarge!,
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.xs),
              Row(
                children: [
                  _Meta(icon: Icons.fact_check_outlined, text: courseKindLabel(course.kind)),
                  if (stats.lessons > 0) ...[
                    const Gap(AppSpacing.sm),
                    _Meta(
                      icon: Icons.groups_outlined,
                      text: '${stats.visited}/${stats.lessons} пар',
                    ),
                  ],
                  const Spacer(),
                  if (stats.total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: passed
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppShapes.small),
                      ),
                      child: Text(
                        'прогноз ${stats.predictedGrade}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: passed
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const Gap(4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

String _num(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);
