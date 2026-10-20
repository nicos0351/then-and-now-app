import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/services/remote_data_service.dart';

void main() {
  final towns = json.decode(File('assets/towns.json').readAsStringSync()) as List<dynamic>;
  final stories = json.decode(File('assets/name_stories.json').readAsStringSync()) as List<dynamic>;

  Map<String, dynamic> payload({int format = 1, int version = 4, List<dynamic>? townList}) => {
        'format': format,
        'dataVersion': version,
        'updated': '2026-11-01',
        'changes': [
          {'version': version, 'date': '2026-11-01', 'summary': 'Test change'},
        ],
        'towns': townList ?? towns,
        'stories': stories,
      };

  test('the bundled data, published as an update, is accepted', () {
    final p = RemotePayload.parse(json.encode(payload()));
    expect(p.dataVersion, 4);
    expect(p.towns.length, towns.length);
    expect(p.changes.single.summary, 'Test change');
  });

  test('an unknown file format is rejected', () {
    expect(() => RemotePayload.parse(json.encode(payload(format: 2))), throwsFormatException);
  });

  test('a truncated file is rejected', () {
    expect(() => RemotePayload.parse(json.encode(payload(townList: towns.take(100).toList()))),
        throwsFormatException);
  });

  test('duplicate town keys are rejected', () {
    final dup = [...towns, towns.first];
    expect(() => RemotePayload.parse(json.encode(payload(townList: dup))), throwsFormatException);
  });

  test('a town outside South Africa is rejected', () {
    final bad = [
      ...towns.skip(1),
      {...(towns.first as Map<String, dynamic>), 'latitude': 51.5, 'longitude': -0.12},
    ];
    expect(() => RemotePayload.parse(json.encode(payload(townList: bad))), throwsFormatException);
  });

  test('garbage is rejected', () {
    expect(() => RemotePayload.parse('<html>404</html>'), throwsFormatException);
  });
}
