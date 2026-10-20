import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../models/name_story.dart';
import '../models/town.dart';
import '../utils/nearest_town.dart';
import 'name_story_section.dart';
import 'plus_teaser.dart';
import 'share_card.dart';

/// Bottom sheet answering "Where am I?": the town you're in (or nearest
/// to) and, with Then & Now Plus, what it used to be called. Pops with a [Town] when the person
/// asks to see a town on the map, or null when dismissed.
class WhereAmISheet extends StatelessWidget {
  const WhereAmISheet({super.key, required this.result, this.story, this.isPlus = false, this.onGetPlus});

  final WhereAmIResult result;

  /// Story/pronunciation for the nearest town, if it has one.
  final NameStory? story;

  /// Without Plus, one teaser replaces the old name and the story;
  /// [onGetPlus] opens the upgrade screen (after this sheet closes).
  final bool isPlus;
  final VoidCallback? onGetPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final town = result.nearest.town;
    final distance = formatDistance(result.nearest.distanceKm);
    void getPlus() {
      Navigator.of(context).pop();
      onGetPlus?.call();
    }

    final String lead;
    String? distanceLine;
    switch (result.proximity) {
      case Proximity.inTown:
        lead = "You're in";
        break;
      case Proximity.nearTown:
        lead = "You're near";
        distanceLine = '$distance away';
        break;
      case Proximity.farFromTown:
        lead = 'The nearest town on the map is';
        distanceLine = '$distance away';
        break;
      case Proximity.outsideSouthAfrica:
        lead = "You seem to be outside South Africa. The nearest town on the map is";
        distanceLine = '$distance away';
        break;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.my_location, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(lead, style: theme.textTheme.labelLarge)),
              ],
            ),
            const SizedBox(height: 4),
            Text(town.currentName, style: theme.textTheme.headlineMedium),
            Text(
              distanceLine == null ? town.province : '${town.province} · $distanceLine',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _NameHistory(town: town, isPlus: isPlus, onGetPlus: getPlus, hasStory: story != null),
            if (story != null && town.hasDifferentOldName && isPlus) ...[
              const SizedBox(height: 16),
              NameStorySection(story: story!, townName: town.currentName, oldName: town.oldName),
            ],
            if (result.nearestRenamed != null) ...[
              const SizedBox(height: 12),
              _NearestRenamedTile(nearby: result.nearestRenamed!, isPlus: isPlus),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (town.hasKnownRename && isPlus)
                  TextButton.icon(
                    onPressed: () => showShareCard(context, town: town, story: story),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(town),
                  icon: const Icon(Icons.place_outlined),
                  label: Text('Show ${town.currentName} on the map'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "then" half: the old name, or a note that there isn't one.
class _NameHistory extends StatelessWidget {
  const _NameHistory({required this.town, required this.isPlus, required this.onGetPlus, required this.hasStory});
  final Town town;
  final bool isPlus;
  final VoidCallback onGetPlus;
  final bool hasStory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (town.hasKnownRename && !isPlus) {
      // Free users learn that the name changed, not what it was.
      final when = town.renamedYear == null ? '' : ' in ${town.renamedYear}';
      return PlusTeaser(
        title: town.hasDifferentOldName
            ? '${town.currentName} was renamed$when. What was it called before?'
            : '${town.currentName} has a name-change story.',
        text: town.hasDifferentOldName && hasStory
            ? 'Previous names, what the new name means and how to say it are part of $kPlusName.'
            : 'Previous names and the history behind them are part of $kPlusName.',
        onUnlock: onGetPlus,
      );
    }

    if (town.hasDifferentOldName) {
      final when = town.renamedYear == null ? 'Formerly known as' : 'Known until ${town.renamedYear} as';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(when, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            const SizedBox(height: 2),
            Text(
              town.oldName,
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            if (town.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                town.notes!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ],
          ],
        ),
      );
    }

    if (town.hasKnownRename && town.notes != null) {
      // Same previous name as today, but with a story (e.g. a reverted rename).
      return Text(town.notes!, style: theme.textTheme.bodyMedium);
    }

    return Text(
      'No name change is on record for ${town.currentName}. If you know of one, open it on the map '
      'and tap the pencil icon to add it.',
      style: theme.textTheme.bodyMedium,
    );
  }
}

class _NearestRenamedTile extends StatelessWidget {
  const _NearestRenamedTile({required this.nearby, required this.isPlus});
  final NearbyTown nearby;
  final bool isPlus;

  @override
  Widget build(BuildContext context) {
    final t = nearby.town;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text('Nearest renamed town: ${t.currentName}'),
        subtitle: Text(isPlus
            ? 'Was ${t.oldName} · ${formatDistance(nearby.distanceKm)} away'
            : '${formatDistance(nearby.distanceKm)} away'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pop(t),
      ),
    );
  }
}
