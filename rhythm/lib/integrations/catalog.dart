import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/integrations/api/bmstu/bmstu_connector.dart';
import 'package:rhythm/integrations/api/tulsu/tulsu_connector.dart';
import 'package:rhythm/integrations/contract/connector.dart';
import 'package:rhythm/integrations/manual/manual_connector.dart';

/// Единственное место регистрации источников. Новый вуз — новая папка
/// в `integrations/` и одна строка здесь; экраны и хранилище не меняются.
const ScheduleConnector tulsuConnector = TulsuConnector();
const ScheduleConnector bmstuConnector = BmstuConnector();
const ScheduleConnector manualConnector = ManualConnector();

const List<ScheduleConnector> sourceConnectors = [
  tulsuConnector,
  bmstuConnector,
  manualConnector,
];

/// Коннекторы, которые пользователь может добавить сам (ручной — отдельным
/// пунктом, а не в общем списке).
List<ScheduleConnector> get selectableConnectors => sourceConnectors
    .where((connector) => connector.descriptor.kind != ConnectorKind.manual)
    .toList();

/// Коннектор источника. Неизвестный id (данные из будущей версии) ведёт себя
/// как ручной, а не падает.
ScheduleConnector connectorFor(Source? source) {
  final id = source?.providerId;
  if (id == null) return manualConnector;
  for (final connector in sourceConnectors) {
    if (connector.id == id) return connector;
  }
  return manualConnector;
}
