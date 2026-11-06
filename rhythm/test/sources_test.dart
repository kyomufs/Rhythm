import 'package:flutter_test/flutter_test.dart';
import 'package:rhythm/core/api/api_exception.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/sources/registry.dart';

Source _source({
  String id = 's1',
  SourceKind kind = SourceKind.university,
  String title = 'ТулГУ',
  String? providerId = 'tulsu',
}) =>
    Source(
      id: id,
      kind: kind,
      title: title,
      subtitle: '221341',
      providerId: providerId,
      config: const {'group': '221341:01'},
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
      expect(restored.config['group'], '221341:01');
    });
  });

  group('реестр провайдеров', () {
    test('в выборе только реальные API-провайдеры', () {
      expect(selectableProviders.map((p) => p.id), contains('tulsu'));
      expect(selectableProviders.map((p) => p.id), isNot(contains('manual')));
      expect(sourceProviders['manual'], isNotNull);
    });

    test('неизвестный источник падает на ручной провайдер', () {
      expect(providerFor(null).id, 'manual');
      expect(providerFor(_source(providerId: 'nope')).id, 'manual');
      expect(providerFor(_source()).id, 'tulsu');
    });

    test('ручной провайдер не отдаёт расписание', () async {
      const provider = manualSourceProvider;
      expect(provider.capabilities, isEmpty);
      expect(provider.marksApi(_source(providerId: null)), isNull);
      expect(
        provider.scheduleApi(_source(providerId: null)).fullSchedule('221341'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
