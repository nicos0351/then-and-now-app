import 'package:flutter/material.dart';

/// Bottom panel for the timeline: drag (or play) from "Then" to
/// "Today" and the map labels change to the names towns had that year.
class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
    super.key,
    required this.year,
    required this.minYear,
    required this.maxYear,
    required this.renamedByYear,
    required this.totalRenamed,
    required this.playing,
    required this.onChanged,
    required this.onPlayPause,
    required this.onClose,
    this.firstYear,
    this.onUnlockEarlier,
  });

  final int year;

  /// The "Then" stop.
  final int minYear;

  /// Where the slider actually starts: [minYear] with Plus, the year after
  /// without it ("Then" is a Plus feature). Null = [minYear].
  final int? firstYear;

  /// Shown as a locked "Then" button when [firstYear] is after
  /// [minYear]; opens the Plus screen.
  final VoidCallback? onUnlockEarlier;

  /// The slider's last stop, labelled "Today".
  final int maxYear;

  /// Renames (with a known year) that had happened by [year].
  final int renamedByYear;
  final int totalRenamed;
  final bool playing;
  final ValueChanged<int> onChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onClose;

  String labelFor(int y) {
    if (y <= minYear) return 'Then';
    if (y >= maxYear) return 'Today';
    return '$y';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = firstYear ?? minYear;
    final locked = start > minYear;
    final subtitle = year <= minYear
        ? 'Every town under its previous name'
        : year >= maxYear
            ? 'Every town under its current name'
            : '$renamedByYear of $totalRenamed renames had happened by the end of $year';

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: playing ? 'Pause' : 'Play through the years',
                  icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36),
                  color: theme.colorScheme.primary,
                  onPressed: onPlayPause,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labelFor(year), style: theme.textTheme.titleLarge),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close timeline',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            Slider(
              value: year.clamp(start, maxYear).toDouble(),
              min: start.toDouble(),
              max: maxYear.toDouble(),
              divisions: maxYear - start,
              label: labelFor(year),
              semanticFormatterCallback: (v) => labelFor(v.round()),
              onChanged: (v) => onChanged(v.round()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (locked)
                    InkWell(
                      onTap: onUnlockEarlier,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 12, color: theme.colorScheme.primary),
                            const SizedBox(width: 2),
                            Text('Then', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                    )
                  else
                    Text('Then', style: theme.textTheme.labelSmall),
                  Text('Today', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Towns whose rename date isn\'t on record change at "Today".',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
