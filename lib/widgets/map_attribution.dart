import 'package:flutter/material.dart';

import '../config/map_tiles.dart';
import '../utils/links.dart';

/// Credit for the place data, shown on the map next to the tile credits.
const geoNamesCredit = TileCredit('GeoNames', 'https://www.geonames.org/');

/// Always-visible attribution strip in the bottom-left corner of the map.
///
/// The OpenStreetMap tile policy requires the credit to be visible on the
/// map itself - not hidden behind a toggle or button - so this is a plain
/// permanent label rather than flutter_map's collapsible
/// `RichAttributionWidget`. It sits bottom-left and wraps to a second line
/// if needed; `MapScreen` lifts the floating action button by
/// [MapAttribution.reservedHeight] so the two never overlap.
/// Each credit opens its source/licence page when tapped.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.credits});

  final List<TileCredit> credits;

  /// Vertical space to keep clear above the bottom edge (two lines).
  static const double reservedHeight = 34;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 10.5, height: 1.2, color: Colors.black.withValues(alpha: 0.8));
    final linkStyle = style.copyWith(decoration: TextDecoration.underline);
    final all = [...credits, geoNamesCredit];

    return Align(
      alignment: Alignment.bottomLeft,
      child: SafeArea(
        top: false,
        right: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          color: Colors.white.withValues(alpha: 0.85),
          // Clamp text scaling so the strip can't outgrow [reservedHeight].
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < all.length; i++) ...[
                  if (i > 0) Text(' · ', style: style),
                  Semantics(
                    link: true,
                    label: '${all[i].text} - open source and licence page',
                    child: GestureDetector(
                      onTap: () => openLink(context, all[i].url),
                      child: Text('© ${all[i].text}', style: linkStyle),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
