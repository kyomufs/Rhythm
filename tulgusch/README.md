# tulgusch

Расписание и итоговая успеваемость ТулГУ с Material 3 Expressive.

## Поддерживаемые платформы

- ✅ iOS
- ✅ Android
- ✅ Windows
- ✅ Linux (Arch + NixOS)
- ✅ Web

## Установка

### Требования

- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio (для Android)
- Xcode (для iOS)
- Visual Studio (для Windows)

### Запуск

```bash
# Установка зависимостей
flutter pub get

# Запуск на разных платформах
flutter run -d android
flutter run -d ios
flutter run -d windows
flutter run -d linux
flutter run -d chrome
```

### Сборка

```bash
# Android APK
flutter build apk

# iOS
flutter build ios

# Windows
flutter build windows

# Linux
flutter build linux
```

## NixOS / Arch Linux

### NixOS (с использованием flake)

```bash
# Вход в dev shell
nix develop

# Или полный dev shell со всеми инструментами
nix develop .#full

# Сборка пакета
nix build
```

### Arch Linux

```bash
# Установка зависимостей
sudo pacman -S flutter dart gtk3 glib pango cairo gdk-pixbuf atk epoxy

# Запуск
flutter run -d linux
```

## Архитектура

```
lib/
├── main.dart           # Точка входа
├── app.dart           # Конфигурация приложения
├── core/              # Ядро приложения
│   ├── api/          # API клиент
│   ├── models/       # Модели данных
│   ├── services/     # Сервисы
│   └── theme/        # MD3 тема
├── features/          # Фичи приложения
│   ├── schedule/     # Расписание, изменения, избранное
│   ├── performance/  # Итоговая успеваемость
│   └── profile/      # Профиль, онбординг, настройки
└── shared/            # Общие виджеты
```

## API

Приложение использует открытый API расписания ТулГУ:

- `GetDictionaries.php` — автодополнение
- `GetDates.php` — диапазон дат
- `GetSchedule.php` — расписание
- `GetCalendar.php` — учебный календарь
- `GetMarks.php` — итоговые оценки (по зачётке и группе)

## Технологии

- **Flutter** — кроссплатформенный фреймворк
- **Riverpod** — управление состоянием
- **Dio** — HTTP клиент
- **Hive** — локальное хранилище
- **Навигация** — `IndexedStack` + нижняя панель (`AppTabs`), без внешнего роутера

## Структура расписания

### Типы занятий

- 📖 **Лекция** — фиолетовый
- 💻 **Практика** — зелёный
- 🔬 **Лабораторная** — оранжевый

### Формат данных

```json
{
  "DATE_Z": "01.09.2026",
  "TIME_Z": "11:35 - 13:10",
  "DISCIP": "Название предмета",
  "KOW": "Лекции",
  "AUD": "Гл.-408",
  "PREP": "ФИО преподавателя",
  "GROUPS": [{"GROUP_P": "221341", "PRIM": ""}],
  "CLASS": "lecture"
}
```

## Лицензия

MIT License
