import 'package:dio/dio.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/integrations/api/bmstu/bmstu_api.dart';
import 'package:rhythm/integrations/contract/connector.dart';

/// МГТУ им. Н. Э. Баумана: расписание из ЛКС, без авторизации.
///
/// Группа задаётся uuid: в ЛКС группы адресуются им, а не номером.
/// Подпись хранится отдельно, чтобы в интерфейсе был «ИУ7-31Б», а не uuid.
class BmstuConnector extends ScheduleConnector {
  const BmstuConnector();

  @override
  ConnectorDescriptor get descriptor => const ConnectorDescriptor(
        id: 'bmstu',
        title: 'МГТУ им. Баумана',
        subtitle: 'Расписание ЛКС',
        kind: ConnectorKind.api,
        targetField: 'groupId',
        capabilities: {
          SourceCapability.directory,
          SourceCapability.schedule,
        },
        fields: [
          ConfigField(
            key: 'groupId',
            label: 'Группа',
            hint: 'ИУ7-31Б',
            helper: 'Начните вводить номер — список придёт из ЛКС',
            required: true,
            searchable: true,
            displayKey: 'groupLabel',
          ),
        ],
      );

  @override
  ScheduleApi scheduleApi(Source source) => BmstuScheduleApi(
        baseUrl: source.config['baseUrl'] ?? BmstuEndpoints.baseUrl,
      );

  @override
  Future<List<ConfigOption>> search(String fieldKey, String query) async {
    if (fieldKey != 'groupId' || query.trim().isEmpty) return const [];
    final suggestions = await BmstuScheduleApi().search(query.trim());
    return suggestions
        .map((item) => ConfigOption(value: item.value, label: item.sort))
        .toList();
  }

  @override
  Future<bool> ping() async {
    final dio = Dio(BaseOptions(
      baseUrl: BmstuEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ));
    try {
      await dio.get<dynamic>(BmstuEndpoints.current);
      return true;
    } on DioException {
      return false;
    }
  }
}
