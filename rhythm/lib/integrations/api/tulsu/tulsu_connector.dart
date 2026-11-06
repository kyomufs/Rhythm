import 'package:dio/dio.dart';
import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/integrations/api/tulsu/tulsu_api.dart';
import 'package:rhythm/integrations/contract/connector.dart';

/// ТулГУ: расписание, календарь и итоговые оценки.
class TulsuConnector extends ScheduleConnector {
  const TulsuConnector();

  @override
  ConnectorDescriptor get descriptor => const ConnectorDescriptor(
        id: 'tulsu',
        title: 'ТулГУ',
        subtitle: 'Расписание и итоговые оценки',
        kind: ConnectorKind.api,
        targetField: 'group',
        capabilities: {
          SourceCapability.directory,
          SourceCapability.schedule,
          SourceCapability.calendar,
          SourceCapability.finalMarks,
          SourceCapability.profile,
        },
        fields: [
          ConfigField(
            key: 'group',
            label: 'Группа',
            hint: '221341',
            helper: 'По номеру группы загружается расписание',
            required: true,
            searchable: true,
          ),
          ConfigField(
            key: 'subgroup',
            label: 'Подгруппа',
            hint: '1 или 2',
          ),
          ConfigField(
            key: 'studentId',
            label: 'Номер зачётки',
            hint: 'Из зачётки или из личного кабинета',
            helper: 'Нужен только для итоговых оценок',
          ),
        ],
      );

  @override
  ScheduleApi scheduleApi(Source source) => TulsuScheduleApi(
        baseUrl: source.config['baseUrl'] ?? TulsuEndpoints.baseUrl,
      );

  @override
  FinalMarksApi? marksApi(Source source) => TulsuFinalMarksApi(
        baseUrl:
            source.config['progressBaseUrl'] ?? TulsuEndpoints.progressBaseUrl,
      );

  @override
  Future<List<ConfigOption>> search(String fieldKey, String query) async {
    if (fieldKey != 'group' || query.trim().isEmpty) return const [];
    final suggestions = await TulsuScheduleApi().search(query.trim());
    return suggestions
        .map((item) => ConfigOption(value: item.value, label: item.value))
        .toList();
  }

  @override
  Future<bool> ping() async {
    try {
      await newDio(TulsuEndpoints.baseUrl).get<dynamic>(
        TulsuEndpoints.dates,
        queryParameters: {'search_value': ''},
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
