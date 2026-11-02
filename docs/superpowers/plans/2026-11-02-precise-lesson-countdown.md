# Точный отсчёт до пары — план реализации

> **Для агентов:** план исполняется инлайн в текущей сессии (пользователь выбрал порядок «план → реализация → сводка»).

**Goal:** отсчёт «До начала пары» и «До конца пары» показывает точное время с секундами и обновляется каждую секунду, а не «примерно в минутах» с шагом 30 с.

**Architecture:** точность обеспечивается в двух местах: модель (`ScheduleItem`) отдаёт остаток как `Duration`, а не округлённые вверх минуты; общий `clockProvider` тикает раз в секунду с привязкой к границе секунды. Тяжёлые виджеты (плитка пары, шторка деталей) подписываются на усечённое до минуты время — они перестраиваются только при смене состояния «идёт / скоро», а секундный текст живёт в отдельных `ConsumerWidget`-блоках отсчёта.

**Tech Stack:** Flutter 3.x, Riverpod 2 (`StateNotifierProvider`), M3 (`ColorScheme`-роли, tonal-контейнеры), Rubik.

**Spec:** запрос оператора в чате: «время до начала пары должно быть точным а не примерным»; дизайн — скиллы `material-3` / `m3-expressive`, m3.material.io.

## Global Constraints

- Только `lib/core/models/schedule.dart`, `lib/core/providers/clock_provider.dart`, `lib/features/schedule/widgets/lesson_tile.dart`, `lib/features/schedule/widgets/lesson_detail_sheet.dart` + новый тест. Никаких попутных рефакторингов.
- Текст UI — по-русски, идентификаторы — по-английски.
- Цвета только из `ColorScheme` (существующие `primaryContainer` / `secondaryContainer`), без хардкода.
- Формат отсчёта: `12 мин 34 с`, `1 ч 05 мин 09 с`, `34 с`; округления вверх нет.
- Секунды в тексте — с табличными цифрами (`FontFeature.tabularFigures()`), чтобы ширина не дёргалась.
- Push на GitHub не делать.

## Review Focus

- Переход «скоро → идёт» на границе минуты: в 08:00:00 плитка уже подсвечена как текущая, в 09:30:00 — уже нет.
- Пары другой даты/неразборчивое время (`time` без `HH:MM`) не должны показывать отсчёт.
- Отсчёт не уходит в отрицательные значения и не перескакивает через 0 при отставании таймера.
- Перерисовка: секундный тик не должен перестраивать все карточки недели.
- Тёмная тема: текст отсчёта остаётся на `onPrimaryContainer` / `onSecondaryContainer`.

---

## Структура файлов

| Файл | Ответственность |
| --- | --- |
| `lib/core/models/schedule.dart` | `timeUntilStartAt` / `timeLeftAt` → `Duration`; `formatCountdown(Duration)` |
| `lib/core/providers/clock_provider.dart` | глобальные часы с тиком 1 с по границе секунды |
| `lib/features/schedule/widgets/lesson_tile.dart` | плитка: минутное состояние + секундные блоки отсчёта |
| `lib/features/schedule/widgets/lesson_detail_sheet.dart` | шторка: то же для баннеров |
| `test/countdown_test.dart` | юнит-тесты остатка и формата |

## Задача 1: точный остаток и формат в модели

**Файлы:** Modify `lib/core/models/schedule.dart:64-79, 381-387`; Test `test/countdown_test.dart`

**Interfaces:**
- Produces: `Duration ScheduleItem.timeUntilStartAt(DateTime now)`, `Duration ScheduleItem.timeLeftAt(DateTime now)`, `String formatCountdown(Duration remaining)`.
- Удаляет: `minutesLeftAt`, `minutesUntilStartAt`, `formatDurationShort` (других потребителей нет).

- [ ] Шаг 1: тест `test/countdown_test.dart` — остаток до старта/конца для `08:00 - 09:30`, нули после конца, формат `12 мин 34 с` / `1 ч 05 мин 09 с` / `34 с`.
- [ ] Шаг 2: прогон — тесты падают (методов нет).
- [ ] Шаг 3: реализация методов и форматтера.
- [ ] Шаг 4: прогон — зелёный.

## Задача 2: секундные часы

**Файлы:** Modify `lib/core/providers/clock_provider.dart`

**Interfaces:**
- Produces: тот же `clockProvider` (`DateTime`), но значение меняется каждую секунду, тик выровнен по границе секунды (`1000 - now.millisecond`), без накопления дрейфа.

- [ ] Шаг 1: заменить `Timer.periodic(30s)` на цепочку `Timer(delay, …)`, перепланируемую после каждого тика.
- [ ] Шаг 2: проверить, что нет утечки таймера при `dispose`.

## Задача 3: плитка и шторка

**Файлы:** Modify `lib/features/schedule/widgets/lesson_tile.dart:32-62, 209-223, 279-375`, `lib/features/schedule/widgets/lesson_detail_sheet.dart:33-52, 179-187, 297-398`

**Interfaces:**
- Consumes: `ScheduleItem.timeUntilStartAt`, `timeLeftAt`, `formatCountdown`; `clockProvider`.
- Produces: `_OngoingCountdown({required ScheduleItem lesson})`, `_UpcomingCountdown({required ScheduleItem lesson})` — `ConsumerWidget`; аналогично баннеры шторки.

- [ ] Шаг 1: плитка смотрит на часы через `select` с усечением до минуты; прогресс и секунды считает блок отсчёта.
- [ ] Шаг 2: текст `До начала пары — 12 мин 34 с`, `До конца пары — 17 мин 34 с`; табличные цифры, вес w700, цвета из `ColorScheme`.
- [ ] Шаг 3: то же в шторке (`Начнётся скоро` / `Идёт сейчас`).

## Задача 4: проверка

- [ ] `flutter analyze` — без новых замечаний.
- [ ] `flutter test` — весь набор зелёный.
- [ ] `flutter run -d linux` — приложение стартует, отсчёт тикает; скриншот `grim` для контроля вёрстки.
