import 'package:flutter_test/flutter_test.dart';
import 'package:entregatudo/version_comparator.dart';

void main() {
  test('compara versões numericamente', () {
    expect(compareVersions('1.5.1', '1.5.0'), greaterThan(0));
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    expect(compareVersions('1.5.1', '1.5.1'), 0);
    expect(compareVersions('1.5.0', '1.5.1'), lessThan(0));
    expect(compareVersions('v1.5.1', '1.5.0'), greaterThan(0));
    expect(compareVersions(' 1.5.1 ', '1.5.1'), 0);
  });

  test('rejeita versões inválidas', () {
    expect(compareVersions('', '1.5.1'), isNull);
    expect(compareVersions('abc', '1.5.1'), isNull);
    expect(compareVersions('1.x.2', '1.5.1'), isNull);
    expect(compareVersions('1..2', '1.5.1'), isNull);
  });
}
