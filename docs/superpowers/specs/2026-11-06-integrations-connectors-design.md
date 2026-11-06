# Rhythm: слой интеграций и канонический контракт расписания

Дата: 2026-11-06. Статус: утверждено, реализуется.

## Задача

Сейчас вуз зашит в приложение: онбординг спрашивает группу, подгруппу и зачётку
ТулГУ, провайдер один, а способ получения данных нигде не выражен. Нужен слой,
который держит много источников и не растёт вместе с их числом:

1. **Каталог источников** с выбором при первом запуске. Способ получения данных —
   свойство источника: `api`, `parsed`, `manual`; он же бейдж в списке.
2. **Вся вузовская логика — в папке вуза.** Ядро о вузе не знает.
3. **Один формат после получения.** Внешний ответ (API или HTML) приводится к
   каноническому документу; приложение работает только с ним.
4. **Готовность к хостингу.** Сейчас коннектор работает в приложении, но контракт
   сериализуемый — вынос коннектора на сервер не меняет ни экраны, ни хранилище.

## Принципы

- Разделение «получить» и «показать»: коннектор отдаёт `ScheduleDocument`,
  приложение мапит его в существующий `ScheduleItem`. Экраны не переписываются.
- Отсутствующее поле — это `null` или `[]`, а не выдуманное значение. Вуз без
  групп пар не ломает карточку: блок просто не рисуется.
- Что источник умеет — объявляет коннектор (`capabilities`), а не экран. В
  самом документе способностей нет: показать «группы пар» можно только тогда,
  когда источник их умеет, и решает это дескриптор.
- Никаких `if (provider.id == 'tulsu')` вне папки ТулГУ.
- Новых зависимостей нет. `http`/`dio` уже есть.

## Структура

```
lib/integrations/
├── catalog.dart                    # единственная точка регистрации
├── contract/connector.dart         # ScheduleConnector, ConnectorDescriptor, ConfigField
├── contract/schedule_document.dart # канонический JSON + маппер в ScheduleItem
├── api/tulsu/tulsu_connector.dart  # дескриптор + сборка запроса
├── api/tulsu/tulsu_api.dart        # HTTP и разбор ответов ТулГУ
├── api/bmstu/bmstu_connector.dart
├── api/bmstu/bmstu_api.dart
├── api/bmstu/week_grid.dart        # недельная сетка → даты
└── manual/manual_connector.dart
```

Вложенность `метод/вуз` выбрана сознательно: методов конечное число, вузов —
нет, и метод виден в пути при чтении диффа. Переезд вуза из `parsed` в `api` —
перемещение папки и одна строка импорта в каталоге.

`lib/core/sources/` остаётся доменом: `Source`, `SourcesNotifier`, кэш,
`source_api.dart` (интерфейсы `ScheduleApi` / `FinalMarksApi` и канонические
модели `SourceSchedule`, `CalendarItem`, `FinalMark`).

## Канонический документ

```json
{
  "schemaVersion": 1,
  "sourceId": "tulsu",
  "sourceTitle": "ТулГУ",
  "target": { "field": "group", "value": "221341" },
  "range": { "from": "2026-09-01", "to": "2027-01-05" },
  "lessons": [
    {
      "date": "2026-11-06",
      "start": "10:10",
      "end": "11:40",
      "subject": "Физика",
      "kind": "lecture",
      "room": "301",
      "teachers": ["Иванов И.И."],
      "groups": [{ "title": "221341", "subgroup": 1 }],
      "stream": null
    }
  ],
  "events": [{ "date": "2026-11-04", "title": "День народного единства" }],
  "origin": "local",
  "fetchedAt": "2026-11-06T15:10:00+03:00"
}
```

- `schemaVersion` проверяется при разборе; другая версия — ошибка схемы.
- `range` может быть `null`: коннектор, который не знает границ семестра, отдаёт
  `null`, приложение берёт текущую неделю ±4.
- `kind`: `lecture | practice | lab | unknown`.
- `origin`: `local | remote` — для диагностики и логов.

## Коннектор

```dart
abstract class ScheduleConnector {
  const ScheduleConnector();

  ConnectorDescriptor get descriptor;
  ScheduleApi get scheduleApi;              // диалог с вузом
  FinalMarksApi? get marksApi => null;      // зачётка, если вуз умеет

  String get id => descriptor.id;
  String get label => descriptor.title;
  Set<SourceCapability> get capabilities => descriptor.capabilities;

  Future<bool> ping() => true;              // доступность, по умолчанию «да»
  Future<List<ConfigOption>> search(String fieldKey, String query) async => [];

  String? targetValue(Source source);       // что подставлять в запрос
  String? targetLabel(Source source);       // что показать в шапке
  String? academicGroup(Source source);     // группа с подгруппой
  String? studentId(Source source);         // зачётка
}

class ConnectorDescriptor {
  final String id;                     // 'tulsu'
  final String title;                  // 'ТулГУ'
  final String? subtitle;              // 'Расписание и оценки'
  final ConnectorKind kind;            // api | parsed | manual
  final String? remoteEndpoint;        // null → исполняется в приложении
  final List<ConfigField> fields;      // анкета: что спросить у пользователя
  final Set<SourceCapability> capabilities; // directory, schedule, calendar, finalMarks, profile
}
```

Коннектор отдаёт не готовый документ, а `ScheduleApi` — четыре метода
(`search`, `dateRange`, `lessons`, `calendar`), которые уже знает `ScheduleService`.
Документ собирается в `fullSchedule` по умолчанию: разбор ответа живёт в коннекторе,
а кэш, отпечатки и журнал изменений остаются прежними.

`fields` — то, что убирает захардкоженный онбординг. ТулГУ объявляет `group`,
`subgroup`, `studentId`; BMSTU — `groupId` (uuid) и `displayKey` подписи; у ручного
полей нет, его `scheduleApi` — `UnavailableScheduleApi`.
Экран добавления и онбординг рендерят форму из дескриптора.

Удалённый коннектор — тот же интерфейс: `POST {endpoint}/schedule` с `connectorId`,
`config` и `range`, ответ — `ScheduleDocument`. Ядро разницы не видит, поэтому
перенос вуза наружу = заполнить `remoteEndpoint` в дескрипторе.

## ТулГУ

Код переезжает из `core/sources/tulsu/tulsu_provider.dart` в
`integrations/api/tulsu/` без изменения поведения: те же эндпоинты, те же
разборы `DATE_Z`, `TIME_Z`, `DISCIP`, `KOW`, `AUD`, `PREP`, `GROUPS`, `CLASS`.
`capabilities`: `directory, schedule, calendar, finalMarks, profile`. Коннектор ничего
не вычисляет — только приводит ответ к документу.

## BMSTU

Проверено вживую 2026-11-06: API публичный, без авторизации.

| Запрос | Ответ |
|---|---|
| `GET /lks-back/api/v1/structure` | 715 КБ дерево `university → filial → … → group` с `uuid`, `abbr`, `course` |
| `GET /lks-back/api/v1/schedules/current` | `term`, `weekNumber`, `weekName`, `semesterStarts`, `semesterEnds` |
| `GET /lks-back/api/v1/schedules/groups/{uuid}/public` | недельная сетка: `day` 1–6, `time` 1–7, `week` = `all`/`ch`/`zn`, `startTime`, `endTime`, `discipline`, `teachers[]`, `audiences[]`, `groups[]` |

Префикс `/api/v1` из публичной документации не работает (SPA отдаёт `index.html`);
рабочий — `/lks-back/api/v1`, взят из бандла `assets/index-B5Uqpx1L.js`.

`week_grid.dart` разворачивает сетку в даты: берём все даты нужного дня недели от
`semesterStarts` до `semesterEnds`, для `ch`/`zn` оставляем совпадающие по чётности
номера недели, `all` — все. Типа пары в ответе нет → `kind: unknown`,
`SourceCapability.directory` в дескрипторе нет — поиск групп пар выключен. Дерево `/structure` кэшируется в памяти на сеанс:
фильтр по `abbr` дешевле повторных запросов.

## Состояние и миграция

- Единственный источник правды для группы, подгруппы и зачётки — `source.config`.
  Ключи объявляет `ConfigField.key`; `ScheduleScreenNotifier` и
  `PerformanceNotifier` читают их у активного источника, а не из `StorageService`.
- Первый старт после обновления: если источников нет, а `myGroup` непустой —
  создаётся `Source(providerId: 'tulsu', config: {group, subgroup, studentId})`.
  Дальше единственный источник правды — `source.config`; старая группа остаётся
  запасным путём только пока источников нет вовсе.
- Кэш расписания: ключ `schedule_cache_<namespace>_<target>`, где namespace —
  `providerId` источника (`tulsu`, `bmstu`, `manual`). У источника без
  `providerId` он пустой: старые ключи остаются читаемыми.

## Онбординг

Пять экранов, но только два из них про вуз:

1. **Приветствие.** Что умеет приложение, кнопка «Начать».
2. **Способ получения.** Чипы `api` / `parsed` / `manual` — фильтр каталога,
   а не отдельный вопрос про вуз.
3. **Учреждение.** Карточки отфильтрованного каталога: название, подпись, бейдж
   метода, «расписание вручную» для источников без `SourceCapability.schedule`.
   Внизу — «Добавить вручную» с полем названия.
4. **Что спросить.** Форма по `descriptor.fields` (`ConnectorFieldForm`): у ТулГУ —
   группа с поиском, подгруппа, зачётка; у BMSTU — группа с автокомплитом по
   `/structure`, в конфиг пишутся `groupId` (uuid) и подпись для шапки.
5. **Готово.** Сводка «источник → цель» и кнопка «Открыть расписание».

Шаги пропускаются, если у выбранного источника нет полей. Пропуск онбординга
остаётся: приложение открывается с ручным источником.

## Ошибки

| Класс | Причина | Поведение |
|---|---|---|
| сеть | таймаут, нет соединения | показываем кэш, сообщение «Нет подключения» |
| схема | ответ не разобрался, чужой `schemaVersion` | кэш с пометкой «данные устарели», «Вуз изменил формат» |
| конфиг | неверная группа/uuid | ведём в настройку источника |

## Тесты

Существующие тесты не переписываются: экраны по-прежнему получают те же модели.
Добавлены два файла:

- `test/integrations_test.dart` — `week_grid` (`ch`/`zn`/`all`, номер недели от
  `semesterStarts`, даты по чётности) и `ScheduleDocument` (JSON round-trip,
  отсутствующие поля → `null`/`[]`, чужая `schemaVersion` → ошибка).
- `test/sources_test.dart` — каталог (у каждого коннектора валидный дескриптор,
  `fields` покрывают ключи, которые он читает), ручной коннектор, `academicGroup`
  с подгруппой.

Тесты, где экран берёт группу у источника, добавляют
`activeSourceProvider.overrideWithValue(...)`: без источника экран честно пуст.

## Порядок работ

1. Контракт и каталог, ручной коннектор.
2. Перенос ТулГУ в `integrations/api/tulsu`, поведение не меняется.
3. `source.config` как источник правды + миграция + ключ кэша.
4. Онбординг на дескрипторах.
5. `week_grid` и коннектор BMSTU.
