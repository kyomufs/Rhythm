# Rhythm: источники, журнал успеваемости и десктопный ввод

Дата: 2026-11-06. Статус: утверждено, реализуется.

## Задача

Приложение перестаёт быть клиентом расписания ТулГУ. Появляются:

1. **Источники** — университет, школа, работа, курсы. Набор источников расширяется
   пользователем, провайдер описывает только то, что источник умеет.
2. **Журнал успеваемости** — семестры, дисциплины, посещение, баллы, дедлайны,
   статистика. Заменяет «заметки» (папки → подпапки → задачи): старые данные не
   ограничивают модель.
3. **Десктопный ввод** — колесо над горизонтальными лентами, панорамирование ЛКМ,
   hover-состояния, горячие клавиши.

## Принципы

- Домен не знает Flutter и не знает провайдеров: `lib/core/domain` — чистый Dart.
- `tulsu.ru` упоминается ровно в двух файлах: `tulsu_provider.dart` и
  `tulsu_mapper.dart`. Экраны работают только с доменом.
- Журнал **локальный по определению**: посещение, баллы и события не приходят из
  API. Поэтому школа и работа работают без провайдера вообще.
- Один активный источник. Переключение — смена контекста, а не настройка.
- Никаких новых зависимостей.

## Источники и провайдеры

```dart
enum SourceKind { university, school, work, courses, other }

enum SourceCapability { directory, schedule, calendar, finalMarks, profile }

class Source {
  final String id;
  final SourceKind kind;
  final String title;        // «ТулГУ», «Школа №8», «Работа»
  final String? subtitle;    // группа, класс, отдел
  final String? providerId;  // null → только ручной ввод
  final Map<String, String> config; // baseUrl, group, studentId…
  final int colorIndex;
  final DateTime createdAt;
}
```

Интерфейсы-возможности (реализуются провайдером опционально):

| Интерфейс | Методы |
|---|---|
| `DirectoryApi` | `search(query) → List<DirectoryEntry>` |
| `ScheduleApi` | `dateRange(ref)`, `lessons(ref, range)`, `calendar(ref)` |
| `FinalMarksApi` | `finalMarks(ref) → List<FinalMark>` |
| `ProfileApi` | `profile(ref) → SourceProfile?` |

`SourceRef` = `{providerId, config}` — то, что нужно провайдеру для запроса.
`SourceProvider` = `Map<SourceCapability, Object?>` + `id` + `label`; реестр
`providerRegistry` — единственное место регистрации. Добавление вуза = новый файл
провайдера + строка в реестре. Если провайдеров станет больше пяти и их API
разойдутся, каждый провайдер получает свой пакет моделей — текущие интерфейсы это
позволяют, потому что домен уже общий.

Провайдеры:
- `manual` — без API, `providerId: null` (школа, работа, курсы);
- `tulsu` — обёртка над существующим `TulsuApiClient`, маппинг в домен.

## Домен журнала

```
Source 1─* Term 1─* Course 1─1 GradeScale
                        │
                        ├─* LessonRecord   (посещение, комментарий, опц. баллы)
                        └─* Assessment      (категория, max, earned, дедлайн)
```

- `Term` — `{id, sourceId, title, start, end, kind: semester|trimester|module|custom, isCurrent}`.
- `Course` — `{id, termId, title, teacher, kind: exam|credit|differentiatedCredit, colorIndex}`.
- `GradeScale` — `{categories: [GradeCategory], passThreshold, rounding}`,
  `GradeCategory` — `{id, name, maxPoints, lessonType?, isExam}`.
  Пресеты: «60 + 40», «30 + 30 + 40 (с лабами)», «100 без экзамена (зачёт)», «кастом».
  Сумма ≠ 100 — предупреждение, не запрет.
- `LessonRecord` — `{id, courseId, date, slot, lessonType, attendance:
  present|absent|excused|late, reason?, comment?, points?}`.
  `slot` — номер пары (1–8), пара определяется парой (дата, slot, courseId).
- `Assessment` — `{id, courseId, categoryId, title, dueDate, heldDate?, maxPoints,
  earnedPoints?, status: planned|graded|missed, comment?, lessonId?}`.

### Производные величины (без хранения)

`CategoryProgress{earned, max}`, `CourseStats{current, currentMax, exam, examMax,
total, percent, predictedGrade, attendancePresent, attendanceTotal, attendancePercent,
nextDeadline, pointsToPass}`, `TermStats`.

Правило: балл категории = сумма `Assessment.earnedPoints` по категории + сумма
`LessonRecord.points` для пар, чей тип совпадает с `lessonType` категории.

## Хранение

Hive, существующий бокс `rhythm`, новые ключи:

- `sources` — `List<Source>` + `activeSourceId`;
- `journal_v1` — `{sourceId: {terms: [...], courses: [...], records: [...], assessments: [...]}}`.

Старые ключи (`study_folders`, `subjects`, `tasks`, `notes`) не читаются новой
моделью и остаются как есть — удаление отдельным решением пользователя.

## Экраны

- **Переключатель источников**: пилюля в шапке (бейдж-инициалы + название),
  тап → модальный лист: список источников с галочкой активного и чипами
  возможностей, ниже разделитель и «Добавить источник». Один источник — пилюля без
  шеврона. На широком экране — тот же список плюс рейл.
- **Журнал** (вкладка вместо заметок): лента семестров (горизонтальная, колесо/драг
  на ПК), карточки дисциплин с прогрессом `42/60`, посещением `12/14` и ближайшим
  дедлайном, FAB «Добавить дисциплину».
- **Дисциплина**: «Сводка» (кольцо/полоса по категориям, прогноз, до зачёта),
  «Посещение» (лента пар по датам, отметки), «События» (дедлайны и баллы),
  «Шкала» (редактор категорий с пресетами).
- **Лист пары в расписании**: блок «Посещение» (сегмент Был/Не был + причина) и
  «Баллы» (скроллер 0…max категории) — пишут в тот же `LessonRecord`.
- **Быстрый ввод балла**: горизонтальный скроллер-пикер (0…max с шагом 1),
  тянется пальцем/мышью, плюс степпер для точной правки.

## Десктопный ввод

`lib/core/input/`:

- `WheelScroll` — горизонтальная прокрутка колесом (и Shift+колесо), с
  `ScrollController`-таргетом;
- `DragPan` — ЛКМ-драг как панорамирование (`ScrollBehavior` + `GestureDetector`
  на desktop, курсор `grab/grabbing`, инерция не изобретается — только drag);
- `HoverRegion` — курсор/hover-подсветка для кликабельных карточек;
- `AppShortcuts` — 1–4 вкладки, ←/→ период, Esc закрывает лист.

Применяется к: ленте семестров, недельному навигатору, чипам дней.

## Тестирование

- домен и статистика — чистые unit-тесты (шкала с весами, посещение, дедлайны);
- хранение — round-trip через фейковое хранилище;
- реестр источников — manual + tulsu + неизвестный providerId;
- UI — журнал (список/дисциплина), переключатель источников, ввод балла;
- десктопный ввод — колесо и драг на тестовом контроллере.

## Вне объёма

- синхронизация журнала между устройствами;
- автозаполнение баллов из API (в API ТулГУ их нет);
- удаление старых заметок и миграция их данных;
- release-сборка (по договорённости — только debug и тесты).
