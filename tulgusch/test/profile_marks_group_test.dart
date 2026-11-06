// Пара для запроса оценок собирается из профиля: группа расписания с
// подгруппой либо отдельная группа для оценок, если она включена.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/services/storage_service.dart';
import 'package:tulgusch/features/profile/providers/profile_providers.dart';

class _Storage extends StorageService {
  _Storage({this.group, this.subgroup, this.marks, this.marksSubgroup});

  final String? group;
  final String? subgroup;
  final String? marks;
  final String? marksSubgroup;

  @override
  String? getMyGroup() => group;

  @override
  String? getMySubgroup() => subgroup;

  @override
  String? getMarksGroup() => marks;

  @override
  String? getMarksSubgroup() => marksSubgroup;
}

String? _pair(StorageService storage) {
  final container = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  return container.read(profileMarksGroupProvider);
}

void main() {
  test('без профиля пары нет', () {
    expect(_pair(_Storage()), isNull);
  });

  test('группа без подгруппы уходит как есть', () {
    expect(_pair(_Storage(group: '221341')), '221341');
  });

  test('подгруппа из поля группы добавляется через двоеточие', () {
    expect(_pair(_Storage(group: '221341', subgroup: '01')), '221341:01');
  });

  test('отдельная группа для оценок перебивает группу расписания', () {
    final storage = _Storage(
      group: '221341',
      subgroup: '01',
      marks: '224001',
      marksSubgroup: '02',
    );

    expect(_pair(storage), '224001:02');
  });

  test('отдельная группа без подгруппы идёт без двоеточия', () {
    final storage = _Storage(group: '221341', marks: '224001');

    expect(_pair(storage), '224001');
  });
}
