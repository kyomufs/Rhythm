import 'package:flutter_test/flutter_test.dart';
import 'package:tulgusch/core/services/update_service.dart';

void main() {
  test('compareVersions orders dotted numeric versions', () {
    expect(UpdateService.compareVersions('1.1.0', '1.0.0'), greaterThan(0));
    expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
    expect(UpdateService.compareVersions('1.0.0', '1.1.0'), lessThan(0));
    // Numeric (not lexicographic) segment comparison.
    expect(UpdateService.compareVersions('1.2.9', '1.10.0'), lessThan(0));
    // Missing segments count as zero.
    expect(UpdateService.compareVersions('2', '1.9.9'), greaterThan(0));
    // Non-numeric junk falls back to zero instead of throwing.
    expect(
        UpdateService.compareVersions('1.0.1-beta', '1.0.0'), greaterThan(0));
  });
}
