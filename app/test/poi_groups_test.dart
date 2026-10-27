import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/poi_groups.dart';

void main() {
  test('every shipped POI category has a group', () {
    final source = File('../content/data/paluma/pois.json').readAsStringSync();
    final json = jsonDecode(source) as Map<String, Object?>;
    final categories = {
      for (final poi in (json['pois'] as List).cast<Map<String, Object?>>())
        poi['category']! as String,
    };

    expect(categories, isNotEmpty);
    for (final category in categories) {
      expect(
        PoiGroup.forCategory(category),
        isNotNull,
        reason: '$category would never be drawn on the map',
      );
    }
  });

  test('no category belongs to two groups', () {
    final seen = <String>{};
    for (final category in PoiGroup.allCategories) {
      expect(
        seen.add(category),
        isTrue,
        reason: '$category is listed twice, so hiding one group could hide it',
      );
    }
  });

  test('hazards stay outside every group so they cannot be hidden', () {
    expect(PoiGroup.forCategory('hazard'), isNull);
    expect(PoiGroup.allCategories, isNot(contains('hazard')));
  });

  test('every schema category is either grouped or a hazard', () {
    final schema = jsonDecode(
      File('../content/schema/pois.schema.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final enumValues =
        ((schema['properties']! as Map<String, Object?>)['pois']!
                as Map<String, Object?>)['items']!
            as Map<String, Object?>;
    final categories =
        ((enumValues['properties']! as Map<String, Object?>)['category']!
                as Map<String, Object?>)['enum']!
            as List;

    for (final category in categories.cast<String>()) {
      if (category == 'hazard') continue;
      expect(
        PoiGroup.forCategory(category),
        isNotNull,
        reason: 'the schema allows $category but no group shows it',
      );
    }
  });
}
