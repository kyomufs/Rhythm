import 'package:uniflow/core/domain/source.dart';
import 'package:uniflow/core/sources/source_api.dart';

/// Провайдер источника: описывает, что источник умеет, и создаёт API под
/// конкретный экземпляр (у двух групп ТулГУ разные настройки).
abstract class SourceProvider {
  const SourceProvider();


  String get id;
  String get label;

  /// Возможности, которые провайдер реально реализует.
  Set<SourceCapability> get capabilities;

  ScheduleApi scheduleApi(Source source);

  FinalMarksApi? marksApi(Source source) => null;

  /// Значение группы/класса для запросов расписания.
  String? groupOf(Source source) => null;

  /// Доступен ли источник по сети. Проверка лёгкая: полный ответ не нужен.
  Future<bool> ping() async => true;
}

/// Источник без API: расписание недоступно, журнал ведётся целиком вручную.
class ManualSourceProvider extends SourceProvider {
  const ManualSourceProvider();

  @override
  String get id => 'manual';

  @override
  String get label => 'Вручную';

  @override
  Set<SourceCapability> get capabilities => const {};

  @override
  ScheduleApi scheduleApi(Source source) => const UnavailableScheduleApi();
}
