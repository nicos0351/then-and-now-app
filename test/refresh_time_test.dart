import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/utils/refresh_time.dart';

void main() {
  final now = DateTime(2026, 10, 9, 14, 30);

  test('describes the last refresh in plain words', () {
    expect(describeLastRefresh(null, now), 'Never');
    expect(describeLastRefresh(DateTime(2026, 10, 9, 8, 5), now), 'Today, 08:05');
    expect(describeLastRefresh(DateTime(2026, 10, 8, 22, 0), now), 'Yesterday, 22:00');
    expect(describeLastRefresh(DateTime(2026, 10, 5, 9, 0), now), '4 days ago');
    expect(describeLastRefresh(DateTime(2026, 9, 1, 9, 0), now), '1 Sep 2026');
  });

  test('flags data not refreshed for a month', () {
    expect(isRefreshStale(null, now), isTrue);
    expect(isRefreshStale(now.subtract(const Duration(days: 29)), now), isFalse);
    expect(isRefreshStale(now.subtract(const Duration(days: 30)), now), isTrue);
  });
}
