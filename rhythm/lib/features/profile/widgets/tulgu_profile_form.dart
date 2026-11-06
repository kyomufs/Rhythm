import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:tulgusch/core/theme/spacing.dart';

/// Профиль ученика ТулГУ: группа, подгруппа и зачётка.
///
/// Группа обязательна — по ней строится расписание; подгруппа уточняет
/// пары, зачётка нужна только итоговым оценкам. Одна форма на первый
/// запуск и на редактирование профиля.
class TulguProfileForm extends StatefulWidget {
  const TulguProfileForm({
    super.key,
    this.initialGroup,
    this.initialSubgroup,
    this.initialStudentId,
    this.autofocus = false,
    this.onChanged,
  });

  final String? initialGroup;
  final String? initialSubgroup;
  final String? initialStudentId;

  /// Ставить ли курсор в поле группы сразу: на первом запуске — да,
  /// при редактировании профиля пользователь уже знает, зачем пришёл.
  final bool autofocus;

  /// Вызывается при любой правке: экран гасит прошлую ошибку, не дожидаясь
  /// повторного «Сохранить».
  final VoidCallback? onChanged;

  @override
  State<TulguProfileForm> createState() => TulguProfileFormState();
}

class TulguProfileFormState extends State<TulguProfileForm> {
  late final _group = TextEditingController(text: widget.initialGroup ?? '');
  late final _subgroup =
      TextEditingController(text: widget.initialSubgroup ?? '');
  late final _studentId =
      TextEditingController(text: widget.initialStudentId ?? '');

  String get group => _group.text.trim();
  String? get subgroup =>
      _subgroup.text.trim().isEmpty ? null : _subgroup.text.trim();
  String? get studentId =>
      _studentId.text.trim().isEmpty ? null : _studentId.text.trim();

  @override
  void dispose() {
    _group.dispose();
    _subgroup.dispose();
    _studentId.dispose();
    super.dispose();
  }

  /// Текст первой ошибки или `null`, если форма заполнена верно.
  String? validate() {
    if (group.isEmpty) return 'Укажите номер группы';
    if (!RegExp(r'^\d{4,8}$').hasMatch(group)) {
      return 'Номер группы — только цифры, например 221341';
    }
    final sub = subgroup;
    if (sub != null && !RegExp(r'^[12]$|^0[12]$').hasMatch(sub)) {
      return 'Подгруппа — 1 или 2';
    }
    final id = studentId;
    if (id != null && !RegExp(r'^\d{4,12}$').hasMatch(id)) {
      return 'Номер зачётки — только цифры';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void changed(String _) => widget.onChanged?.call();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _group,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: changed,
          decoration: const InputDecoration(
            labelText: 'Группа',
            hintText: '221341',
            helperText: 'По ней строится расписание',
            prefixIcon: Icon(Icons.groups_2_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(AppSpacing.sm),
        TextField(
          controller: _subgroup,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: changed,
          decoration: const InputDecoration(
            labelText: 'Подгруппа',
            hintText: '1 или 2',
            helperText: 'Необязательно: уточняет пары и оценки',
            prefixIcon: Icon(Icons.call_split_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(AppSpacing.sm),
        TextField(
          controller: _studentId,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: changed,
          decoration: const InputDecoration(
            labelText: 'Номер зачётки',
            hintText: 'из деканата',
            helperText: 'Необязательно: нужен только итоговым оценкам',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          'Данные хранятся только на этом устройстве.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
