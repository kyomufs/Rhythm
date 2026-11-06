// Поведение экрана успеваемости без сети и без данных: пустой ответ вуза
// не должен стирать сохранённые оценки, а по умолчанию открывается
// последний семестр, а не первый.
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/app.dart';
import 'package:tulgusch/core/api/schedule_api.dart';
import 'package:tulgusch/core/models/marks.dart';
import 'package:tulgusch/core/services/connectivity_service.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/core/services/update_coordinator.dart';
import 'package:tulgusch/features/performance/providers/performance_provider.dart';

MarksItem _mark(String discipline, {String term = '3'}) => MarksItem(
      term: term,
      discipline: discipline,
      mark: '5',
      markTitle: 'отлично',
      teacherMark: '5',
      retake: '',
      recredit: false,
    );

FinalMark _finalMark(String discipline, {String term = '4'}) => FinalMark(
      term: term,
      discipline: discipline,
      markTitle: 'отлично',
      teacherMark: '5',
    );

Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void invalidateCache() {}
}

class _Api implements FinalMarksApi {
  _Api(this.result);

  final List<FinalMark> result;
  int calls = 0;
  String? lastGroup;

  @override
  Future<List<FinalMark>> finalMarks({
    required String studentId,
    required String group,
  }) async {
    calls++;
    lastGroup = group;
    return result;
  }
}

class _Storage extends StorageService {
  _Storage({this.cached});

  List<MarksItem>? cached;
  int cacheWrites = 0;

  @override
  List<MarksItem>? getCachedMarks({
    required String studentId,
    required String group,
  }) =>
      cached;

  @override
  Future<void> cacheMarks({
    required String studentId,
    required String group,
    required List<MarksItem> marks,
  }) async {
    cacheWrites++;
    cached = marks;
  }
}

PerformanceNotifier _notifier(_Api api, _Storage storage) => PerformanceNotifier(
      api,
      storage,
      UpdateCoordinator(_OnlineConnectivity()),
      studentId: '000000',
      group: '221341',
    );

void main() {
  test('пустой ответ не затирает сохранённые оценки', () async {
    final storage = _Storage(cached: [_mark('Из кэша')]);
    final api = _Api(const []);

    final notifier = _notifier(api, storage);
    await _flush();

    expect(api.calls, 1);
    expect(notifier.state.marks.single.discipline, 'Из кэша',
        reason: 'пустой ответ вуза не повод терять снимок');
    expect(notifier.state.serverEmpty, isTrue);
    expect(notifier.state.error, isNull);
    expect(storage.cacheWrites, 0);
  });

  test('пустой ответ без кэша даёт объяснимое состояние, а не ошибку',
      () async {
    final storage = _Storage();
    final api = _Api(const []);

    final notifier = _notifier(api, storage);
    await _flush();

    expect(notifier.state.marks, isEmpty);
    expect(notifier.state.serverEmpty, isTrue);
    expect(notifier.state.error, isNull);
  });

  test('успешный ответ кэшируется и снимает флаг пустоты', () async {
    final storage = _Storage(cached: [_mark('Из кэша', term: '3')]);
    final api = _Api([_finalMark('Свежее', term: '4')]);

    final notifier = _notifier(api, storage);
    await _flush();

    expect(notifier.state.marks.single.discipline, 'Свежее');
    expect(notifier.state.serverEmpty, isFalse);
    expect(storage.cacheWrites, 1);
    expect(storage.cached!.single.discipline, 'Свежее');
  });

  test('по умолчанию открыт последний семестр', () async {
    final storage = _Storage(cached: [
      _mark('Старый курс', term: '1'),
      _mark('Текущий курс', term: '6'),
    ]);
    final api = _Api(const []);

    final notifier = _notifier(api, storage);
    await _flush();

    expect(notifier.state.selectedSemester, 6);
    expect(notifier.state.semesterMarks.single.discipline, 'Текущий курс');
  });

  test('переходы между вкладками не выходят за пределы оболочки', () {
    for (final index in [
      AppTabs.schedule,
      AppTabs.performance,
      AppTabs.profile,
    ]) {
      expect(index, inInclusiveRange(0, MainShell.tabCount - 1));
    }
    expect(AppTabs.performance, isNot(AppTabs.profile));
  });
}
