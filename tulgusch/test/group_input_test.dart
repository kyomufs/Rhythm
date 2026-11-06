// Поле группы принимает и чистый номер, и полный индекс с подгруппой.
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/features/profile/utils/group_input.dart';

void main() {
  test('пустое поле не задаёт ни группу, ни подгруппу', () {
    final parsed = GroupInput.parse('   ');

    expect(parsed.group, isNull);
    expect(parsed.subgroup, isNull);
    expect(parsed.pair, isNull);
  });

  test('чистый номер остаётся группой', () {
    final parsed = GroupInput.parse('221341');

    expect(parsed.group, '221341');
    expect(parsed.subgroup, isNull);
    expect(parsed.pair, '221341');
  });

  test('индекс отделяется двоеточием', () {
    final parsed = GroupInput.parse('221341:01');

    expect(parsed.group, '221341');
    expect(parsed.subgroup, '01');
    expect(parsed.pair, '221341:01');
  });

  test('одна цифра индекса дополняется нулём', () {
    expect(GroupInput.parse('221341:1').pair, '221341:01');
  });

  test('буквенный индекс сохраняется как есть', () {
    expect(GroupInput.parse('221341:иу').subgroup, 'иу');
    expect(GroupInput.parse('221341:иу').pair, '221341:иу');
  });

  test('пробелы вокруг двоеточия не мешают', () {
    final parsed = GroupInput.parse(' 221341 : 2 ');

    expect(parsed.group, '221341');
    expect(parsed.subgroup, '02');
  });
}
