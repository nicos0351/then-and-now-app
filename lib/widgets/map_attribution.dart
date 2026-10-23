import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
///
/// With MapTiler's maps, MapTiler's free plan also requires its logo on the
/// map, linking to maptiler.com. The official logo is loaded from MapTiler
/// (like the map itself), so it's always their current version.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.credits});

  final List<TileCredit> credits;

  /// Vertical space to keep clear above the bottom edge (two lines).
  static const double reservedHeight = 38;

  /// MapTiler's official logo (see docs.maptiler.com, "MapTiler
  /// attribution and how to add it").
  static const mapTilerLogoUrl = 'https://api.maptiler.com/resources/logo.svg';

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 10.5, height: 1.2, color: Colors.black.withValues(alpha: 0.8));
    final linkStyle = style.copyWith(decoration: TextDecoration.underline);
    final all = [...credits, geoNamesCredit];
    final mapTiler = credits.any((c) => c.text == 'MapTiler');

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
                if (mapTiler)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Semantics(
                      link: true,
                      label: 'MapTiler - open maptiler.com',
                      child: GestureDetector(
                        onTap: () => openLink(context, 'https://www.maptiler.com/'),
                        child: SvgPicture.network(
                          mapTilerLogoUrl,
                          height: 16,
                          semanticsLabel: 'MapTiler logo',
                          placeholderBuilder: (_) => const SizedBox(height: 16, width: 64),
                        ),
                      ),
                    ),
                  ),
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
