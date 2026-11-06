import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/api/api_exception.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/integrations/catalog.dart';

Source _source({
  String id = 's1',
  SourceKind kind = SourceKind.university,
  String title = 'ТулГУ',
  String? providerId = 'tulsu',
  Map<String, String> config = const {'group': '221341', 'subgroup': '01'},
}) =>
    Source(
      id: id,
      kind: kind,
      title: title,
      subtitle: '221341',
      providerId: providerId,
      config: config,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  group('источник', () {
    test('бейдж — две буквы или инициалы', () {
      expect(_source(title: 'ТулГУ').badge, 'ТУ');
      expect(_source(title: 'Школа 14').badge, 'Ш1');
      expect(_source(title: 'К').badge, 'К');
    });

    test('ручной источник и json-круговорот', () {
      final manual = _source(providerId: null);
      expect(manual.isManual, isTrue);
      final restored = Source.fromJson(manual.toJson());
      expect(restored.id, manual.id);
      expect(restored.kind, manual.kind);
      expect(restored.providerId, isNull);
      expect(restored.config['group'], '221341');
    });
  });

  group('каталог коннекторов', () {
    test('в выборе только сетевые источники', () {
      expect(selectableConnectors.map((c) => c.id), contains('tulsu'));
      expect(selectableConnectors.map((c) => c.id), contains('bmstu'));
      expect(selectableConnectors.map((c) => c.id), isNot(contains('manual')));
      expect(sourceConnectors.map((c) => c.id), contains('manual'));
    });

    test('неизвестный источник ведёт себя как ручной', () {
      expect(connectorFor(null).id, 'manual');
      expect(connectorFor(_source(providerId: 'nope')).id, 'manual');
      expect(connectorFor(_source()).id, 'tulsu');
    });

    test('ручной коннектор не отдаёт расписание и оценки', () async {
      const connector = manualConnector;
      expect(connector.capabilities, isEmpty);
      expect(connector.marksApi(_source(providerId: null)), isNull);
      expect(
        connector.scheduleApi(_source(providerId: null)).fullSchedule('221341'),
        throwsA(isA<ApiException>()),
      );
    });

    test('группа собирается из номера и подгруппы', () {
      final connector = connectorFor(_source());
      expect(connector.targetValue(_source()), '221341');
      expect(connector.academicGroup(_source()), '221341:01');
      expect(
        connector.academicGroup(_source(config: const {'group': '221341'})),
        '221341',
      );
    });
  });
}
