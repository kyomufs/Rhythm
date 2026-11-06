import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/utils/mark_labels.dart';

void main() {
  test('нормализация снимает регистр, «ё» и лишние пробелы', () {
    expect(normalizeMarkTitle('  Отлично '), 'отлично');
    expect(normalizeMarkTitle('Зачёт'), 'зачет');
    expect(normalizeMarkTitle('Не  аттестован'), 'не аттестован');
  });

  test('известные аттестации сокращаются', () {
    expect(shortMarkTitle('Отлично'), 'Отл.');
    expect(shortMarkTitle('хорошо'), 'Хор.');
    expect(shortMarkTitle('Удовлетворительно'), 'Удовл.');
    expect(shortMarkTitle('Зачёт'), 'Зач.');
    expect(shortMarkTitle('Незачет'), 'Незач.');
    expect(shortMarkTitle('Не аттестован'), 'Не атт.');
  });

  test('неизвестная формулировка из API остаётся как есть', () {
    expect(shortMarkTitle(' Академическая задолженность '),
        'Академическая задолженность');
    expect(shortMarkTitle(''), '');
  });
}
