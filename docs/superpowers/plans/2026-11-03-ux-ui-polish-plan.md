# Rhythm: план UX/UI-полировки на M3 Expressive

**Дата:** 2026-11-03
**Статус:** план на ревью оператора
**Класс:** UX/UI-полировка поверх уже внедрённого фундамента M3E
**Скиллы:** `m3-expressive` (значения), `m3-expressive-impl` (код и моушен)
**Спека-предшественник:** [2026-11-03-rhythm-m3-expressive-design.md](../specs/2026-11-03-rhythm-m3-expressive-design.md)

---

## 1. Цель и критерий успеха

Не «переписать дизайн», а довести уже работающий M3E-фундамент до консистентности: убрать
расхождения с токенами, выстроить иерархию экранов, ограничить моушен бюджетом и закрыть
доступность.

Успех =

1. Ни одного «магического» числа в геометрии компонентов: высоты, радиусы, отступы иконок
   берутся из токенов (`shapes.dart`, новый `spacing.dart`), а не из локальных `EdgeInsets`.
2. Все интерактивные анимации разрешаются в одну из шести spring-токенов; `Duration` + `Curves`
   остаются только там, где виджет физически не принимает пружину (и это помечено комментарием).
3. Каждый экран проходит ручной чек-лист: 320dp ширины, textScale 1.0 / 1.5 / 2.0, светлая и
   тёмная схема, reduce-motion включён.
4. `flutter analyze` без новых замечаний, `flutter test` зелёный, `flutter run -d linux`
   запускается и проверен визуально.

---

## 2. Что уже сделано — не переделывать

| Слой | Состояние |
|---|---|
| `lib/core/theme/motion.dart` | 6 spring-токенов expressive + standard, `SpringDrive`, `springDuration`, гейт `MotionScheme.of` |
| `lib/core/theme/shapes.dart` | 10-шаговая шкала радиусов + `inner(outer, padding)` |
| `lib/core/theme/typography.dart` | baseline `TextTheme` + `emphasized*` из токенов |
| `lib/core/theme/theme_provider.dart` | единый `_buildTheme` для обеих схем, 20+ компонентных тем |
| `lib/shared/widgets/app_nav_bar.dart` | своя нижняя панель на `unbounded`-контроллере и пружине |
| Кэш / обновление / демо | stale-while-revalidate, `UpdateCoordinator`, честные демо-данные |

Задача плана — **не** трогать эту архитектуру, а вычистить то, что поверх неё ещё не выровнено.

---

## 3. Аудит: что именно не так (по коду, не по ощущениям)

Severity: **P1** — видно глазом или ломает токен-систему; **P2** — консистентность; **P3** — код-качество.

| # | S | Находка | Файл:строка | Чем чинится |
|---|---|---|---|---|
| 1 | P1 | `displayLarge` tracking `−0.25` вместо `−0.2`; `titleMedium` `0.15` вместо `0.2`; `bodyMedium` `0.25` вместо `0.2` | `typography.dart:14,21,24` | Таблица baseline из `tokens.md` |
| 2 | P1 | `emphasized()` считает tracking эвристикой `+0.05` — для `bodyLarge` это `0.55` вместо `0.15`, для `bodySmall` `0.45` вместо `0.4` | `typography.dart:86-97` | Табличный маппинг emphasized-tracking |
| 3 | P1 | Нижняя панель: высота контента 58dp, индикатор 32→64dp с радиусом 28, зазор иконка↔подпись 2dp | `app_nav_bar.dart:37,140-145,164` | `ContainerHeight` 64, индикатор 56×32 `CornerFull`, `ContainerBetweenSpace` 6 |
| 4 | P1 | Кнопки: `vertical: 14` даёт ~48dp, радиус 20; нет морфа формы при нажатии | `theme_provider.dart:169-188` | `ContainerHeight` 40, `CornerFull`/`CornerMedium`, `PressedContainerShape` `CornerSmall` |
| 5 | P2 | FAB: радиус 20 вместо `CornerLarge` 16 | `theme_provider.dart:161-168` | Токен FAB |
| 6 | P2 | Карточки: радиус 20 на информационно-плотных карточках — срезает контент | `theme_provider.dart:100-111` | `CornerMedium` 12 для карточек, 20 остаётся только контейнеру дня |
| 7 | P1 | Онбординг: `Duration(400ms)` + `Curves.easeInOut`, `AnimatedContainer(300ms)` — мимо spring-системы | `onboarding_screen.dart:47,58,156` | `slow.spatial` для смены страницы, `default.spatial` для карточки |
| 8 | P2 | Настройки: `AnimatedContainer(200ms)` на переключателе темы | `settings_screen.dart:93` | `defaultEffects` (цвет) / `fastSpatial` (размер) |
| 9 | P2 | Индикатор загрузки — штатный `CircularProgressIndicator`; M3E-индикатор (7 фигур) не реализован | `loading_indicator.dart:27` | M3E loading indicator из `m3-expressive-impl` |
| 10 | P2 | Нет шкалы отступов: в коде живут 2/3/6/10/14 рядом с 4/8/12/16/24/32 | весь `lib/features` | `lib/core/theme/spacing.dart` + замена |
| 11 | P2 | Хардкод размеров текста мимо `TextTheme`: `9.5`, `10`, `13`, `16`, `18` | `lesson_tile.dart:97`, `subject_detail_screen.dart:1439,1488`, `onboarding_screen.dart:202,284,324,373` | `labelSmall`/`bodyMedium`/`titleMedium` |
| 12 | P2 | Две палитры параллельно: `AppTheme.lectureColor/practiceColor/labColor` и `subjectColors[10]` | `app_theme.dart:8-10`, `note_models.dart:243` | Один источник цветов предметов |
| 13 | P2 | `Colors.white` поверх палитрового цвета субъекта — контраст не гарантирован на всех 10 цветах | `notes_screen.dart:520`, `settings_screen.dart:109` | Пара `on*`-роли или вычисление контраста |
| 14 | P2 | Экраны успеваемости: ряд `FilterChip` в `ListView` высотой 56 без семантики single-select; статистика — три текста без иерархии | `performance_screen.dart:167,179,207` | `headlineSmall` emphasized для чисел, чипы по токену 32dp |
| 15 | P3 | `subject_detail_screen.dart` — 1549 строк в одном файле: редактор, задачи, вложения, диалоги | `subject_detail_screen.dart` | Разбить на 4-5 виджет-файлов без изменения поведения |
| 16 | P2 | Пустые состояния продублированы дословно: иконка 80 + `headlineSmall` w600 + текст + кнопка | `schedule_screen.dart:179-190`, `performance_screen.dart:70-90` | `shared/widgets/empty_state.dart` |

---

## 4. Сигналы сообщества: что берём в план

Полные тексты страниц не выгружались — сетевой доступ в этой среде отдаёт непубличные адреса,
поэтому ниже только то, что подтверждено выдачей (заголовок + сниппет). Ссылки — для проверки.

| Источник | Совет | Что делаем |
|---|---|---|
| [r/UXDesign: UI spacing system needs help](https://www.reddit.com/r/UXDesign/comments/1clj3m9/ui_spacing_system_needs_help/) | «сначала держи отступы консистентными, потом пойми, что отступ между карточками ≠ отступ заголовок→контент» | Шкала `spacing.dart` + правило: gap между карточками 8, заголовок→контент 4, секция→секция 24 |
| [r/UI_Design: Sizing & spacing](https://www.reddit.com/r/UI_Design/comments/sbtz5y/sizing_spacing_essential_needtoknows/) | 8px-сетка для размеров и отступов, line-height кратен 4/8 | Сетка 4dp (минимум M3 — 4), все `EdgeInsets` из токенов; line-height уже из шкалы |
| [7 Common UI Design Mistakes](https://spaceberry.studio/blog/common-user-interface-mistakes-and-how-to-do-it-right) | слабые акценты, нет тип-иерархии, тесные отступы, смешанные радиусы | Этапы 2 и 4: один акцент на экран, emphasized только на исключении, радиусы из шкалы |
| [r/UXDesign: как проводят UX-аудит](https://www.reddit.com/r/UXDesign/comments/p6s8qt/how_do_you_usually_conduct_ux_audit_of_an/) | аудит → приоритизация → точечные фиксы, а не редизайн целиком | Раздел 3 уже отсортирован по severity; этапы идут от P1 к P3 |
| [Android Authority: читатели о M3E](https://www.androidauthority.com/material-3-expressive-dislike-3608927/), [dev.to: почему Expressive может быть промахом](https://dev.to/pranta/why-apples-liquid-glass-and-googles-expressive-uis-might-be-missteps-42fa) | главная претензия — перебор анимации и «слишком громко»; движения мешают | Моушен-бюджет: 1 hero-момент на продукт, остальное — `fast`/`default`, ноль bounce на цвете |
| [FlutterCook: миграция больших приложений на M3E](https://fluttercook.github.io/blog/flutter-migrate-material3-expressive/) | поэтапный роллаут, компонентные темы, golden-тесты | Этапы ниже идут слоями (токены → компоненты → экраны), без «большого взрыва» |
| [r/FlutterDev: как делать UI самому](https://www.reddit.com/r/FlutterDev/comments/rltdow/how_do_you_make_ui_as_an_independent_dev/) | UI — итеративный процесс: прототип → показать → починить поток | После каждого этапа — прогон на linux и ручной чек-лист, а не финальный «big review» |

---

## 5. Принципы плана

1. **Токен или комментарий.** Любое число в UI либо из `shapes/spacing/typography/motion`, либо
   помечено как дизайн-решение с обоснованием.
2. **Моушен-бюджет.** Один hero-момент на продукт. Всё остальное — служебное движение
   (`fast` для чипов/кнопок/переключателей, `default` для шторок и карточек).
3. **Эмфазис — исключение.** Baseline-шкала основная; emphasized только на выбранном,
   заголовках блоков и primary-действиях.
4. **Контраст и цель.** Тач-таргет ≥48dp, текст ≥4.5:1, крупный ≥3:1. Цвет никогда не
   единственный носитель смысла.
5. **Никаких новых зависимостей.** Всё делается на `flutter/physics` и встроенных виджетах.

---

## 6. Этапы

### Этап 0. Базовая линия (0.5 дня)

- Базовая линия уже снята 2026-11-03: `flutter analyze` → `No issues found!`, `flutter test` →
  `All tests passed!` (50 тестов). Повторять перед каждым этапом.
- `flutter run -d linux`, скриншоты четырёх вкладок в светлой и тёмной схеме — база для сравнения.

**DoD:** цифры analyze/test и 8 скриншотов лежат в `docs/superpowers/plans/assets/` (или в issue).

### Этап 1. Токены: типографика и отступы (1 день)

1. `typography.dart`: tracking по таблице baseline (`displayLarge −0.2`, `titleMedium 0.2`,
   `bodyMedium 0.2`); `emphasized()` переписать с эвристики на таблицу
   (`bodyLarge 0.15`, `bodyMedium 0.25`, `bodySmall 0.4`, title/label без изменений).
2. Новый `lib/core/theme/spacing.dart`:

```dart
/// Сетка 4dp. M3 не публикует шкалу отступов — это дизайн-решение,
/// согласованное с шагом радиусов и line-height.
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
```

3. Тест `test/typography_tokens_test.dart`: значения 15 baseline + 15 emphasized совпадают с
   таблицей; `emphasized()` не меняет размер и line-height.

**DoD:** тест зелёный, `grep -rn "fontSize: [0-9]" lib` пуст (кроме `typography.dart`).

### Этап 2. Компонентная геометрия (1.5 дня)

Правки только в `theme_provider.dart` + `app_nav_bar.dart`; экраны не трогаются.

| Компонент | Сейчас | Станет (токен) |
|---|---|---|
| Нижняя панель | 58dp, индикатор 32→64, r28, gap 2 | 64dp, индикатор 56×32 `CornerFull`, gap 6, иконка 24 |
| Filled/Outlined/Text button | ~48dp, r20 | 40dp, `CornerFull` (round) / `CornerMedium` (square), pressed → `CornerSmall` |
| FAB | r20 | 56×56, `CornerLarge` 16, elevation Level3 |
| Card | r20 | `CornerMedium` 12, elevation 0, обводка `outlineVariant` 1dp |
| Chip | 32dp ✓ | 32dp, `CornerSmall` 8, `LeadingIconSize` 18 (без изменений) |
| SegmentedButton | — | 40dp, `CornerFull`, иконка 18 (для переключателей в заметках) |
| Sheet / Dialog | 28 ✓ | 28 `CornerExtraLargeTop` / `CornerExtraLarge` (без изменений) |

**From M3:** все значения колонки «Станет» — из `component-tokens.md`.
**My design decision (не в M3):** индикатор нижней панели анимируется по ширине пружиной
`fast.spatial`, а не мгновенно — сохраняем текущее поведение, меняя только конечную геометрию.

**DoD:** визуальная проверка панели и кнопок; `AppShapes.inner(20, 4) == 16` держится в блоке дня.

### Этап 3. Моушен-бюджет (1 день)

1. Онбординг: `PageView` + `AnimatedContainer` → пружины. Смена страницы — `slow.spatial`
   (полный экран), карточка выбора — `default.spatial`, точки-индикатор — `fastSpatial`.
2. Настройки: переключатель темы — `defaultEffects` на цвет, `fastSpatial` на размер.
3. Hero-момент (один на продукт): **переход «Сегодня» в расписании** — заголовок недели
   перестраивается и день подсвечивается одной пространственной пружиной. Больше hero-моментов
   не добавляем.
4. Проверить, что каждая анимация читает `MediaQuery.disableAnimationsOf` (или `MotionScheme.of`).

**DoD:** `grep -rn "Curves\.\|Duration(milliseconds: [0-9]" lib` даёт только `clock_provider`
(тикающие часы) и `motion.dart`; тест `motion_reduce_test.dart` подтверждает standard-схему при
`disableAnimations`.

### Этап 4. Иерархия и состояния экранов (2 дня)

| Экран | Что делаем |
|---|---|
| Расписание | Шапка: номер группы `titleMedium` emphasized; четыре `IconButton` при ширине <360dp уходят в overflow-меню; пустое состояние → общий `EmptyState` |
| Заметки | Палитра субъектов → один источник (`subjectColors`), `Colors.white` → `on*`-роль по контрасту; `subject_detail_screen` разбить на `note_editor.dart`, `task_list.dart`, `attachments_section.dart` |
| Успеваемость | Числа статистики — `headlineSmall` emphasized, подписи — `labelMedium`; чипы семестров получают `Semantics(selected: ...)`; пустое состояние → `EmptyState` |
| Профиль | Настройки: строки `ListTile` с `minVerticalPadding` из `spacing.md`; секции разделены `lg`, а не `Divider` подряд |
| Общее | `shared/widgets/empty_state.dart` (иконка 64 + `titleMedium` + `bodyMedium` + опциональная кнопка) |

**DoD:** расписание и успеваемость используют один `EmptyState`; в заметках один источник цветов; textScale 2.0
не ломает ни одну карточку.

### Этап 5. M3E loading indicator (1 день)

- Заменить `CircularProgressIndicator` в `loading_indicator.dart` на индикатор из
  `m3-expressive-impl`: 7 фигур (`softBurst`, `cookie9Sided`, `pentagon`, `pill`, `sunny`,
  `cookie4Sided`, `oval`), морф ~650 мс на фигуру, глобальный поворот ~4.66 с, глиф 38dp в
  контейнере 48dp.
- Гейт: при `disableAnimations` — одна статичная фигура, без морфа и вращения.
- Inline-вариант (`InlineLoadingIndicator`) остаётся компактным: глиф 20dp в 24dp.

**My design decision (не в M3):** фигуры реализуются через `CustomPainter` и полигоны,
нормализованные в бокс 0..1 — без новых зависимостей.

**DoD:** индикатор виден на загрузке расписания и оценок; при reduce-motion не двигается.

### Этап 6. Доступность и финальная полировка (1 день)

- Тач-таргеты: все кастомные `InkWell`/`GestureDetector` ≥48dp (панель, чипы дня, стрелки недели).
- Контраст: прогнать 10 цветов палитры против `surface` и `on*`-пар; спорные — заменить на
  `primary/secondary/tertiary`-контейнеры.
- `Semantics` для иконочных действий без `tooltip` и для выбранных чипов.
- Тёмная схема: проверить, что `surfaceContainerLow` карточек не сливается с `surface` фона
  (сейчас разница только обводкой).

**DoD:** ручной чек-лист пройден, спорных пар «текст на цвете» не осталось.

---

## 7. Проверка

```
nix develop --command bash -c "flutter analyze && flutter test"
nix develop --command flutter run -d linux
```

Ручной чек-лист на каждом этапе:

1. 320dp ширины — шапка расписания не переполняется.
2. textScale 1.0 / 1.5 / 2.0 — карточки пары, статистика, настройки.
3. Светлая и тёмная схема — контраст текста и границ.
4. Reduce-motion включён — ни морфа, ни bounce, ни вращения.
5. Нижняя панель: индикатор 56×32, подпись на 6dp ниже иконки, активная подпись `secondary`.
6. Кнопки: высота 40, при нажатии форма сжимается до `CornerSmall`.

Тесты, которые добавляются: `typography_tokens_test.dart`, `motion_reduce_test.dart`,
`spacing_scale_test.dart` (все значения кратны 4).

---

## 8. Вне скоупа и риски

**Не входит:** новые продуктовые фичи, новые зависимости, изменения CI, push в GitHub,
переделка кэша/обновления/демо (уже сделано), iOS-проверка на устройстве (нет Xcode).

| Риск | Митигация |
|---|---|
| Геометрия кнопок 40dp может «пожать» онбординг с крупным текстом | Проверка на textScale 2.0 до коммита этапа; при переполнении — `minimumSize`, а не откат токена |
| M3E loading indicator — самый дорогой пункт по коду | Этап 5 изолирован: если не влезает в бюджет, индикатор остаётся штатным, остальное не блокируется |
| Разбиение `subject_detail_screen.dart` может задеть поведение | Только перемещение виджетов, без правки логики; `schedule_ui_test.dart` и ручной прогон редактора заметок |
| Эмфазис на всех заголовках вернёт «громкость», о которой пишут в обзорах M3E | Правило: emphasized максимум на 3 элементах экрана |

---

## 9. Порядок и оценка

| Этап | Объём | Зависит от |
|---|---|---|
| 0. Базовая линия | 0.5 дня | — |
| 1. Токены типографики и отступов | 1 день | 0 |
| 2. Компонентная геометрия | 1.5 дня | 1 |
| 3. Моушен-бюджет | 1 день | 1, 2 |
| 4. Иерархия экранов | 2 дня | 1, 2 |
| 5. Loading indicator | 1 день | 3 |
| 6. Доступность и полировка | 1 день | 2–5 |

Итого ~8 рабочих дней. Этапы 1–2 дают максимум визуального эффекта на единицу работы —
если бюджет урезается, режем 5 и 4, но не 1–3.

---

## 10. Что сделано по факту (2026-11-03)

Этапы 1–3, 5, 6 закрыты, этап 4 закрыт частично. Ниже — что именно и где план
разошёлся с кодом; расхождения записаны, а не замазаны.

| Этап | Статус | Файлы |
|---|---|---|
| 0. Базовая линия | готово | `flutter analyze` → `No issues found!`, `flutter test` → 50 тестов |
| 1. Токены типографики и отступов | готово | `lib/core/theme/typography.dart` (табличная база + emphasized, эвристика `size<=16 → w700` удалена), `lib/core/theme/spacing.dart` (новый), `test/typography_tokens_test.dart` (7 тестов) |
| 2. Компонентная геометрия | готово | `lib/core/theme/shapes.dart` (карточка 12, `pressedButtonRadius` 8), `lib/core/theme/theme_provider.dart` (`_buttonShape` — морф `StadiumBorder` → `CornerSmall` по `WidgetState.pressed`, кнопки 40dp, FAB 16), `lib/shared/widgets/app_nav_bar.dart` (64dp, индикатор 56×32, зазор 6) |
| 3. Моушен-бюджет | готово | онбординг: `slowSpatial` на смену страницы, `defaultEffects` на точки; настройки: `defaultEffects` на выбор цвета |
| 4. Иерархия и состояния | готово | `lib/shared/widgets/empty_state.dart` (новый; используется в расписании и успеваемости), `Semantics(selected:)` на чипах семестров, числа статистики — `headlineSmall` emphasized + `labelMedium` |
| 5. M3E loading indicator | готово | `lib/shared/widgets/expressive_loading_indicator.dart` (новый), `loading_indicator.dart`, три экрана со спиннером переведены на него |
| 6. Доступность | готово частично | `lib/core/theme/color_utils.dart` (`onColorFor` по яркости) вместо `Colors.white` в настройках и заметках; `fontSize:` в `lib/` больше нет ни одного — всё через роли `TextTheme` |

### Расхождения с планом — осознанные

1. **Hero-момент другой.** В плане (этап 3.3) им был переход «Сегодня» в расписании.
   При реализации выяснилось, что `_scrollToDay` намеренно идёт с `Duration.zero`:
   анимация скролла ломается при перестройке списка после синхронизации. Hero-момент
   переехал на M3E loading indicator + индикатор нижней панели. Скролл не тронут.
2. **`PageView` не принимает пружину.** `_nextPage`/`_prevPage` используют
   `springDuration(slowSpatial)` как длительность и `Curves.easeOutCubic` как кривую —
   это ближайшее, что даёт штатный `PageController`.
3. **Палитры не объединены.** `AppTheme`-цвета типов пар и `subjectColors` заметок
   описывают разные домены (тип занятия vs папка предмета); сводить их в один список
   значило бы менять смысл, а не чинить дублирование.
4. **Разбиение экрана предмета — три файла, а не четыре.** В плане значился
   `attachments_section.dart`, но вложений в заметках нет вовсе (ни модели, ни UI),
   поэтому вынесено то, что реально есть: `overview_tab.dart`, `task_list.dart`,
   `task_sheet.dart`. `subject_detail_screen.dart` — 1549 → 405 строк, поведение
   не менялось (только видимость классов поднята до публичной).
5. **Фигуры индикатора — полярные функции, не SVG.** У всех семи фигур по 64 точки,
   морф = интерполяция радиусов; так масштаб не «дышит» и не нужны внешние ассеты.
6. **Узкая шапка расписания и два переполнения.** Ниже 360dp четыре действия
   складываются в `PopupMenuButton` «⋮» с теми же пунктами. Тест на 320dp вскрыл
   реальные overflow: заголовок недели рядом с чипом чётности и бейдж аудитории
   в паре. Починено: `Flexible` с ellipsis у текста недели и `FittedBox(scaleDown)`
   у бейджа аудитории.

### Проверка после правок

```
nix develop --command bash -c "flutter analyze"   # No issues found!
nix develop --command bash -c "flutter test"      # 69 тестов, All tests passed!
nix develop --command bash -c "flutter build linux --debug"  # Built build/linux/x64/debug/bundle/rhythm
```

Новые тесты: `test/m3_expressive_theme_test.dart` — геометрия панели и кнопок,
standard-схема при `disableAnimations`, морф и reduce-motion индикатора, семь фигур
в боксе 0..1, `EmptyState` на textScale 2.0.

## Третий заход: дата в шапке дня, группы в карточке пары, таблица оценок

Три правки после живого прогона на десктопе.

1. **День недели и дата в одну строку.** В шапке карточки дня был `Column`
   из двух `Text`; заменён на один `Text.rich`: день (`titleSmall` w700) и дата
   (`titleSmall` w400, `onSurfaceVariant`) в одну строку с `ellipsis`.
   `DateFormat.EEEE` отдаёт lowercase — добавлен `_capitalize`.
2. **Группы пары для поиска по группе.** Причина бага подтверждена запросами к API:
   `GetSchedule.php?search_field=GROUP_P` возвращает `GROUPS` только с искомой
   группой (для `221341:01` — `[{"GROUP_P":"221341:01","PRIM":""}]`), тогда как тот
   же предмет по `search_field=AUD` (аудитория `Гл.-408`) отдаёт все 10 групп пары.
   Клиентских данных о согруппниках в ответе нет вообще, поэтому нужен второй запрос.
   Решение: `LessonGroupResolver` + `lessonGroupsProvider` (`FutureProvider.family`
   по `date/time/subject/classroom`). Лист пары при `groups.length <= 1` и непустой
   аудитории дозапрашивает расписание аудитории, находит пару по дате/времени/предмету
   и показывает объединённый список; своя группа сортируется первой и подсвечена
   `primaryContainer`. Кэш — LRU на 12 аудиторий (один запрос на аудиторию за сессию).
3. **Оценки — прокручиваемая таблица.** Новый `MarksTable`
   (`lib/features/performance/widgets/`): липкая шапка 48dp, вертикальный `ListView`
   строк, горизонтальный `SingleChildScrollView` по всему блоку, ширины столбцов
   тянутся за 12dp-захват в шапке (`DragStartBehavior.down`, минимум у каждого
   столбца, двойной тап — сброс). Свободное место отдаётся «Дисциплине», но после
   первой ручной правки растяжение выключается — иначе оно съедало бы сдвиг.
   Столбец «Пересдача» скрывается, если пересдач в семестре нет. Старая `_MarkTile`
   удалена, чипы семестров и строка статистики не менялись.

Отклонение от плана: вместо метода в `ScheduleService` — отдельный сервис.
Причина: `ScheduleService` реализуется фейками в двух тестах, добавление метода
ломало бы их ради одной фичи.

### Проверка после правок

```
nix develop --command bash -c "flutter analyze"   # No issues found! (ran in 1.5s)
nix develop --command bash -c "flutter test"      # 76 тестов, All tests passed!
nix develop --command bash -c "flutter build linux --debug"  # Built build/linux/x64/debug/bundle/rhythm
```

Новые тесты: `test/marks_table_test.dart` — шапка и строки, скрытие пустой
«Пересдачи», ресайз столбца и сброс двойным тапом, кламп по минимуму, горизонтальная
прокрутка на 360dp; в `test/schedule_ui_test.dart` — «день и дата в одной строке»
и «группы пары добираются из расписания аудитории».

## Релиз 1.2.0

- Аттестации сокращены до аббревиатур: `normalizeMarkTitle` + `shortMarkTitle`
  в `lib/core/utils/mark_labels.dart` (Отл./Хор./Удовл./Зач./Незач./Не атт.).
  Неизвестная формулировка из API отдаётся как есть. Цвет оценки сравнивается
  по нормализованной подписи, поэтому «зачёт» больше не теряет цвет.
- Столбец «Аттестация» стал уже: 130dp вместо 160dp, минимум 92dp.
- Версия `1.2.0+3`, тег `v1.2.0`. Workflow `release.yml` собрал APK и IPA,
  опубликовал релиз и сам переписал `sidestore/source.json` (version 1.2.0,
  size 9252850, URL на `Rhythm-v1.2.0.ipa`).
