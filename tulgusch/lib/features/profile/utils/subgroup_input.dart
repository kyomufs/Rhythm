/// Разбор поля «подгруппа» в профиле ТулГУ.
///
/// Вуз адресует успеваемость парой «группа:подгруппа», поэтому пользователь
/// может ввести как голую подгруппу (`01`), так и полный формат
/// (`111111:01`). Обе формы приводятся к одной: группа отдельно, подгруппа
/// двумя цифрами.
class SubgroupInput {
  const SubgroupInput({this.group, this.subgroup});

  /// Группа из полного формата, если пользователь её указал.
  final String? group;

  /// Подгруппа в виде `01`/`02` либо `null`, если поле пустое.
  final String? subgroup;

  static SubgroupInput parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const SubgroupInput();

    final colon = text.lastIndexOf(':');
    final prefix = colon > 0 ? text.substring(0, colon).trim() : '';
    final tail = colon >= 0 ? text.substring(colon + 1).trim() : text;

    return SubgroupInput(
      group: prefix.isEmpty ? null : prefix,
      subgroup: _normalize(tail),
    );
  }

  static String? _normalize(String digits) {
    final value = int.tryParse(digits);
    if (value == null) return digits.isEmpty ? null : digits;
    return value.toString().padLeft(2, '0');
  }
}
