import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/sources/source_api.dart';
import 'package:rhythm/integrations/contract/connector.dart';

/// Ручной источник: школа, работа, курсы. Расписания из сети у него нет,
/// поэтому все сетевые возможности выключены, а данные живут в журнале.
class ManualConnector extends ScheduleConnector {
  const ManualConnector();

  @override
  ConnectorDescriptor get descriptor => const ConnectorDescriptor(
        id: 'manual',
        title: 'Вручную',
        subtitle: 'Школа, работа, курсы — без API',
        kind: ConnectorKind.manual,
        targetField: 'title',
        fields: [],
        capabilities: {},
        defaultKind: SourceKind.other,
      );

  @override
  ScheduleApi scheduleApi(Source source) => const UnavailableScheduleApi(
        'Источник без API: расписание вносится вручную',
      );
}
