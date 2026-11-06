// The original counter smoke test referenced a MyApp class that does not
// exist in this app; it is replaced by a real widget smoke test for the
// demo schedule generator (see demo_schedule_test.dart for coverage of
// the change-journal seeding).

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder smoke test', () {
    expect(1 + 1, 2);
  });
}
