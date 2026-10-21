import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../config/map_tiles.dart';
import '../utils/links.dart';
import '../utils/refresh_time.dart';

/// "About & credits": what the app shows and where its data comes from.
/// GeoNames data is CC BY 4.0, which requires this credit in the app (or
/// store listing); the map tile credit is also shown on the map itself.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.tileSource, this.lastRefreshed, this.dataVersion = 0});

  final MapTileSource tileSource;

  /// When the town data was last refreshed (null = never on this phone).
  final DateTime? lastRefreshed;

  /// Version of the town data on this phone.
  final int dataVersion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About & credits')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              '$kAppName shows towns across South Africa under their current '
              'names and, where a town has been renamed, under its previous name. '
              'Flip the whole map with the button at the bottom, or tap a town to see its other name.',
              style: textTheme.bodyMedium,
            ),
          ),
          const _SectionHeader('Town data'),
          ListTile(
            leading: Icon(
              isRefreshStale(lastRefreshed, DateTime.now()) ? Icons.sync_problem : Icons.sync,
              color: isRefreshStale(lastRefreshed, DateTime.now()) ? Theme.of(context).colorScheme.error : null,
            ),
            title: Text('Last refreshed: ${describeLastRefresh(lastRefreshed, DateTime.now())}'),
            subtitle: Text(
              lastRefreshed == null
                  ? 'Showing the place names that came with the app (data version $dataVersion). '
                      'Use ⋮ → Refresh data on the map to get the latest names.'
                  : 'Data version $dataVersion. Use ⋮ → Refresh data on the map to check for newer names.',
            ),
          ),
          const _SectionHeader('Map'),
          for (final credit in tileSource.credits)
            _CreditTile(
              icon: Icons.map_outlined,
              title: '© ${credit.text}',
              subtitle: credit == MapTileSource.osmCredit
                  ? 'Map data is available under the Open Database Licence.'
                  : 'Map tiles provided by ${tileSource.name}.',
              url: credit.url,
            ),
          const _CreditTile(
            icon: Icons.public,
            title: 'Country outline: Natural Earth',
            subtitle: 'Province and border outlines shown where map tiles can\'t load. Public domain.',
            url: 'https://www.naturalearthdata.com/',
          ),
          const _SectionHeader('Towns'),
          const _CreditTile(
            icon: Icons.place_outlined,
            title: 'Place data © GeoNames',
            subtitle: 'Town names, positions and populations from geonames.org, '
                'used under the Creative Commons Attribution 4.0 licence (CC BY 4.0).',
            url: 'https://www.geonames.org/',
          ),
          const _CreditTile(
            icon: Icons.gavel_outlined,
            title: 'CC BY 4.0 licence',
            subtitle: 'creativecommons.org/licenses/by/4.0',
            url: 'https://creativecommons.org/licenses/by/4.0/',
          ),
          const _SectionHeader('Airports, dams and passes'),
          const _CreditTile(
            icon: Icons.flight_outlined,
            title: 'Data © OpenStreetMap contributors',
            subtitle: 'Airports, dams and mountain passes from OpenStreetMap, available under the '
                'Open Database Licence (ODbL), with dam and pass lists checked against Wikipedia. '
                'Their facts (heights, capacities, rivers, codes) come from Wikidata (CC0), '
                'OpenStreetMap and Wikipedia.',
            url: 'https://www.openstreetmap.org/copyright',
          ),
          const _SectionHeader('Name changes'),
          const _CreditTile(
            icon: Icons.history_edu_outlined,
            title: 'Renamed places in South Africa',
            subtitle: 'Rename details were checked against published lists of renamed places and '
                'news reports of the Government Gazette notices. Official names are decided by the '
                'South African Geographical Names Council and the Minister of Sport, Arts and Culture.',
            url: 'https://en.wikipedia.org/wiki/List_of_renamed_places_in_South_Africa',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Some recent renames are still being reviewed or challenged; their notes say so. '
              'Changes you record yourself in the app are marked with a person icon and stay on this device. '
              '"Where am I?" uses your location only on this phone to find the nearest town - it is never '
              'stored or sent anywhere. About once a week (or when you tap Refresh data) the app downloads '
              'the latest place names from GitHub; nothing about you is sent.',
              style: textTheme.bodySmall,
            ),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context, applicationName: kAppName),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.icon, required this.title, required this.subtitle, required this.url});

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => openLink(context, url),
    );
  }
}
