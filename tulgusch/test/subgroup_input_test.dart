// Подгруппа вводится либо голыми цифрами, либо полным форматом вуза
// «группа:подгруппа». Оба варианта должны давать одну и ту же пару.
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/features/profile/utils/subgroup_input.dart';

void main() {
  test('пустое поле не задаёт ни группу, ни подгруппу', () {
    final parsed = SubgroupInput.parse('   ');

    expect(parsed.group, isNull);
    expect(parsed.subgroup, isNull);
  });

  test('одна цифра дополняется нулём', () {
    expect(SubgroupInput.parse('1').subgroup, '01');
    expect(SubgroupInput.parse('2').subgroup, '02');
  });

  test('две цифры остаются как есть', () {
    expect(SubgroupInput.parse('01').subgroup, '01');
  });

  test('полный формат разделяется на группу и подгруппу', () {
    final parsed = SubgroupInput.parse('111111:00');

    expect(parsed.group, '111111');
    expect(parsed.subgroup, '00');
  });

  test('пробелы вокруг двоеточия не мешают', () {
    final parsed = SubgroupInput.parse(' 111111 : 2 ');

    expect(parsed.group, '111111');
    expect(parsed.subgroup, '02');
  });

  test('двоеточие без подгруппы оставляет только группу', () {
    final parsed = SubgroupInput.parse('111111:');

    expect(parsed.group, '111111');
    expect(parsed.subgroup, isNull);
  });
}
