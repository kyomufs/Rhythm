import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:tulgusch/core/theme/spacing.dart';
import 'package:tulgusch/features/profile/utils/group_input.dart';

/// Профиль ученика ТулГУ: группа, зачётка и необязательная группа для оценок.
///
/// Группа принимается с индексом подгруппы (`221341:01`): расписание берёт
/// часть до двоеточия, успеваемость — всю пару. Отдельная группа для оценок
/// включается тумблером и работает так же.
class TulguProfileForm extends StatefulWidget {
  const TulguProfileForm({
    super.key,
    this.initialGroup,
    this.initialSubgroup,
    this.initialMarksGroup,
    this.initialMarksSubgroup,
    this.initialStudentId,
    this.autofocus = false,
    this.onChanged,
  });

  final String? initialGroup;
  final String? initialSubgroup;

  /// Группа для успеваемости, если она отличается от группы расписания.
  final String? initialMarksGroup;
  final String? initialMarksSubgroup;
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
  late final _group = TextEditingController(text: _initialGroupText);
  late final _marksGroup =
      TextEditingController(text: _initialMarksGroupText);
  late final _studentId =
      TextEditingController(text: widget.initialStudentId ?? '');

  /// Отдельная группа для успеваемости включается только осознанно:
  /// по умолчанию оценки ищутся по группе расписания.
  late bool _separateMarksGroup =
      (widget.initialMarksGroup ?? '').trim().isNotEmpty;

  String get _initialGroupText => _join(
        widget.initialGroup,
        widget.initialSubgroup,
      );

  String get _initialMarksGroupText => _join(
        widget.initialMarksGroup,
        widget.initialMarksSubgroup,
      );

  static String _join(String? group, String? subgroup) {
    if (group == null || group.isEmpty) return '';
    if (subgroup == null || subgroup.isEmpty) return group;
    return '$group:$subgroup';
  }

  GroupInput get _groupInput => GroupInput.parse(_group.text);
  GroupInput get _marksInput => GroupInput.parse(_marksGroup.text);

  String? get group => _groupInput.group;
  String? get subgroup => _groupInput.subgroup;
  String? get marksGroup =>
      _separateMarksGroup ? _marksInput.group : null;
  String? get marksSubgroup =>
      _separateMarksGroup ? _marksInput.subgroup : null;
  String? get studentId =>
      _studentId.text.trim().isEmpty ? null : _studentId.text.trim();

  @override
  void dispose() {
    _group.dispose();
    _marksGroup.dispose();
    _studentId.dispose();
    super.dispose();
  }

  /// Текст первой ошибки или `null`, если форма заполнена верно.
  String? validate() {
    if (group == null) return 'Укажите группу';
    if (!RegExp(r'^\d{4,8}$').hasMatch(group!)) {
      return 'Группа — цифры, например 121212 или 121212:00';
    }
    if (_separateMarksGroup) {
      final marks = marksGroup;
      if (marks == null) return 'Укажите группу для оценок';
      if (!RegExp(r'^\d{4,8}$').hasMatch(marks)) {
        return 'Группа для оценок — цифры, например 221341';
      }
    }
    final id = studentId;
    if (id != null && !RegExp(r'^\d{4,12}$').hasMatch(id)) {
      return 'Номер зачётки — только цифры';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    void changed(String _) => widget.onChanged?.call();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _group,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
          ],
          onChanged: changed,
          decoration: const InputDecoration(
            labelText: 'Группа',
            hintText: '121212:00',
            prefixIcon: Icon(Icons.groups_2_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(AppSpacing.sm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Отдельная группа для оценок'),
          value: _separateMarksGroup,
          onChanged: (value) {
            setState(() => _separateMarksGroup = value);
            changed('');
          },
        ),
        if (_separateMarksGroup) ...[
          TextField(
            controller: _marksGroup,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
            onChanged: changed,
            decoration: const InputDecoration(
              labelText: 'Группа для оценок',
              hintText: '121212:00',
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
            hintText: '343434',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
