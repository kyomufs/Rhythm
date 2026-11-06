/// Разбор поля «группа» в профиле ТулГУ.
///
/// Вуз адресует успеваемость парой «группа:подгруппа», поэтому и группа
/// расписания, и группа для оценок принимают либо чистый номер (`221341`),
/// либо полный индекс (`221341:01`). Разбор общий: обе формы приводятся
/// к паре, а не к строке с двоеточием внутри.
class GroupInput {
  const GroupInput({this.group, this.subgroup});

  /// Часть до двоеточия.
  final String? group;

  /// Часть после двоеточия: `01`, `1` → `01`, буквенный индекс — как есть.
  final String? subgroup;

  static GroupInput parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const GroupInput();

    final colon = text.indexOf(':');
    final head = (colon >= 0 ? text.substring(0, colon) : text).trim();
    final tail = colon >= 0 ? text.substring(colon + 1).trim() : '';

    return GroupInput(
      group: head.isEmpty ? null : head,
      subgroup: _normalize(tail),
    );
  }

  static String? _normalize(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    return number == null ? text : number.toString().padLeft(2, '0');
  }

  /// Группа в виде, который ждёт API: `221341` или `221341:01`.
  String? get pair {
    final head = group;
    if (head == null) return null;
    final tail = subgroup;
    return tail == null ? head : '$head:$tail';
  }
}
