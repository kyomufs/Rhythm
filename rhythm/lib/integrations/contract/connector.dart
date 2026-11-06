import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/sources/source_api.dart';

/// Как источник получает данные. Показывается бейджем в списке источников
/// и определяет, что именно ломается, когда вуз обновляет свой сайт.
enum ConnectorKind {
  api('API'),
  parsed('Парсер'),
  manual('Вручную');

  const ConnectorKind(this.badge);

  final String badge;

  String get label => badge;
}

/// Поле анкеты источника. Экран рисует форму по этому списку и не знает,
/// какой именно вуз перед ним: у ТулГУ есть подгруппа, у Бауманки — нет.
class ConfigField {
  final String key;
  final String label;
  final String? hint;
  final String? helper;

  /// Без значения источник не сможет отдать расписание.
  final bool required;

  /// Значение выбирается из подсказок коннектора (группа, аудитория),
  /// а не печатается вручную.
  final bool searchable;

  /// Куда сохранить подпись выбранного значения, если ключ — идентификатор
  /// (BMSTU хранит uuid группы, а показывать надо «ИУ7-31Б»).
  final String? displayKey;

  const ConfigField({
    required this.key,
    required this.label,
    this.hint,
    this.helper,
    this.required = false,
    this.searchable = false,
    this.displayKey,
  });
}

/// Подсказка для поля с `searchable`.
class ConfigOption {
  final String value;
  final String label;
  final String? subtitle;

  const ConfigOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

/// Паспорт коннектора: всё, что ядру нужно знать об источнике, не заглядывая
/// в его код.
class ConnectorDescriptor {
  final String id;
  final String title;
  final String? subtitle;
  final ConnectorKind kind;

  /// Не null — коннектор исполняется на нашем сервере, приложение ходит сюда.
  final String? remoteEndpoint;

  /// Ключ [Source.config], по которому запрашивается расписание.
  final String targetField;

  final List<ConfigField> fields;
  final Set<SourceCapability> capabilities;

  /// Тип источника по умолчанию: вуз, школа и т. п.
  final SourceKind defaultKind;

  const ConnectorDescriptor({
    required this.id,
    required this.title,
    required this.targetField,
    required this.fields,
    required this.capabilities,
    this.subtitle,
    this.kind = ConnectorKind.api,
    this.remoteEndpoint,
    this.defaultKind = SourceKind.university,
  });

  bool get isRemote => remoteEndpoint != null;

  bool get hasSchedule => capabilities.contains(SourceCapability.schedule);

  ConfigField? field(String key) {
    for (final item in fields) {
      if (item.key == key) return item;
    }
    return null;
  }
}

/// Коннектор — единственное место, где живёт знание о вузе.
///
/// Наружу он отдаёт только канонические модели из `source_api.dart`, поэтому
/// экраны и хранилище не меняются при добавлении источника.
abstract class ScheduleConnector {
  /// Константный конструктор нужен, чтобы коннекторы каталога были
  /// `const`-значениями.
  const ScheduleConnector();

  ConnectorDescriptor get descriptor;

  String get id => descriptor.id;

  String get label => descriptor.title;

  Set<SourceCapability> get capabilities => descriptor.capabilities;

  ScheduleApi scheduleApi(Source source);

  FinalMarksApi? marksApi(Source source) => null;

  /// Доступность источника. false — «нет сети», а не «источник удалён».
  Future<bool> ping() => Future<bool>.value(true);

  /// Подсказки для поля `searchable`.
  Future<List<ConfigOption>> search(String fieldKey, String query) async =>
      const <ConfigOption>[];

  /// Значение, по которому строится расписание (номер группы, uuid).
  String? targetValue(Source source) {
    final raw = source.config[descriptor.targetField];
    if (raw == null) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  /// Подпись цели для списка источников: «ИУ7-31Б» вместо uuid.
  String? targetLabel(Source source) {
    final field = descriptor.field(descriptor.targetField);
    final displayKey = field?.displayKey;
    if (displayKey != null) {
      final display = source.config[displayKey];
      if (display != null && display.isNotEmpty) return display;
    }
    return targetValue(source);
  }

  /// Группа в формате API оценок: номер с подгруппой через двоеточие.
  /// Подгруппа необязательна — без неё возвращается просто номер.
  String? academicGroup(Source source) {
    final group = targetValue(source);
    if (group == null) return null;
    final subgroup = source.config['subgroup']?.trim() ?? '';
    return subgroup.isEmpty ? group : '$group:$subgroup';
  }

  /// Номер зачётки, если коннектор его использует.
  String? studentId(Source source) {
    final value = source.config['studentId']?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}
