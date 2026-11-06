import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:tulgusch/core/theme/spacing.dart';
import 'package:tulgusch/features/profile/utils/subgroup_input.dart';

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
    this.initialMarksGroup,
    this.initialStudentId,
    this.autofocus = false,
    this.onChanged,
  });

  final String? initialGroup;
  final String? initialSubgroup;

  /// Группа для успеваемости, если она отличается от группы расписания.
  final String? initialMarksGroup;
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
  late final _marksGroup =
      TextEditingController(text: widget.initialMarksGroup ?? '');
  late final _studentId =
      TextEditingController(text: widget.initialStudentId ?? '');

  /// Отдельная группа для успеваемости включается только осознанно:
  /// по умолчанию оценки ищутся по группе расписания.
  late bool _separateMarksGroup =
      (widget.initialMarksGroup ?? '').trim().isNotEmpty;

  String get group => _group.text.trim();

  SubgroupInput get _subgroupInput => SubgroupInput.parse(_subgroup.text);

  /// Подгруппа нормализуется к двум цифрам: `1`, `01`, `111111:01` → `01`.
  String? get subgroup => _subgroupInput.subgroup;

  /// Группа для оценок: отдельная, если включена, иначе выведенная из
  /// подгруппы в полном формате, иначе `null` — берётся группа расписания.
  String? get marksGroup {
    final explicit = _marksGroup.text.trim();
    if (_separateMarksGroup && explicit.isNotEmpty) return explicit;
    return _subgroupInput.group;
  }

  String? get studentId =>
      _studentId.text.trim().isEmpty ? null : _studentId.text.trim();

  @override
  void dispose() {
    _group.dispose();
    _subgroup.dispose();
    _marksGroup.dispose();
    _studentId.dispose();
    super.dispose();
  }

  /// Текст первой ошибки или `null`, если форма заполнена верно.
  String? validate() {
    if (group.isEmpty) return 'Укажите номер группы';
    if (!RegExp(r'^\d{4,8}$').hasMatch(group)) {
      return 'Номер группы — только цифры, например 111111';
    }
    final marks = marksGroup;
    if (_separateMarksGroup) {
      if (marks == null || marks.isEmpty) {
        return 'Укажите группу для успеваемости или выключите отдельную группу';
      }
      if (!RegExp(r'^\d{4,8}$').hasMatch(marks)) {
        return 'Группа для успеваемости — только цифры, например 111111';
      }
    }
    final sub = subgroup;
    if (sub != null && !RegExp(r'^[12]$|^0[12]$').hasMatch(sub)) {
      return 'Подгруппа — 01 или 02 (можно в полном формате 111111:00)';
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
            hintText: '111111',
            helperText: 'Без подгруппы: по ней строится расписание',
            helperMaxLines: 2,
            prefixIcon: Icon(Icons.groups_2_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(AppSpacing.sm),
        TextField(
          controller: _subgroup,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
          ],
          onChanged: (value) {
            // Полный формат задаёт и группу для оценок — перерисовываем
            // подсказку, чтобы это было видно сразу.
            setState(() {});
            changed(value);
          },
          decoration: const InputDecoration(
            labelText: 'Подгруппа при наличии',
            hintText: '111111:00',
            helperText: 'Можно в полном формате: группа:подгруппа',
            helperMaxLines: 2,
            prefixIcon: Icon(Icons.call_split_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(AppSpacing.sm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Отдельная группа для успеваемости'),
          subtitle: const Text('Если оценки смотрят по другой группе'),
          value: _separateMarksGroup,
          onChanged: (value) {
            setState(() => _separateMarksGroup = value);
            changed('');
          },
        ),
        if (_separateMarksGroup) ...[
          TextField(
            controller: _marksGroup,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: changed,
            decoration: const InputDecoration(
              labelText: 'Группа для оценок',
              hintText: '111111',
              helperText: 'Расписание останется по группе выше',
              prefixIcon: Icon(Icons.assessment_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const Gap(AppSpacing.sm),
        ],
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
