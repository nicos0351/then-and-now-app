import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/place_facts.dart';
import 'package:sa_town_names/services/dam_levels_service.dart';

void main() {
  test('debug', () async {
    print('DBG start');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    print('DBG delayed ok');
    final page = File('test/fixtures/dws_wc.html').readAsStringSync();
    final sw = Stopwatch()..start();
    final p = parseDwsPage(page);
    print('DBG parse ${p.length} in ${sw.elapsedMilliseconds} ms');
    final s = DamLevelsService.forTest(
      fetch: (_) async {
        print('DBG fetch called');
        return page;
      },
      secondTryAfter: const Duration(milliseconds: 50),
      giveUpAfter: const Duration(milliseconds: 300),
    );
    print('DBG service made');
    final r = await s.levelFor(const DamStation(key: 'x', region: 'WC', station: 'H6R001')).timeout(const Duration(seconds: 5), onTimeout: () {
      print('DBG levelFor timed out');
      return const DamLevelResult.failed(DamLevelProblem.offline);
    });
    print('DBG result ${r.level?.thisWeek?.percent} ${r.problem}');
    fail('debug run');
  }, timeout: const Timeout(Duration(seconds: 20)));
}
