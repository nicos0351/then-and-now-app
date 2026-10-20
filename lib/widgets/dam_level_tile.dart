import 'package:flutter/material.dart';

import '../models/place_facts.dart';
import '../services/dam_levels_service.dart';
import '../utils/links.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// A dam's weekly level (Plus), fetched from the Department of Water and
/// Sanitation's website when the dam's sheet opens. Shows nothing if the
/// dam isn't in this week's report.
class DamLevelTile extends StatefulWidget {
  const DamLevelTile({super.key, required this.station});

  final DamStation station;

  @override
  State<DamLevelTile> createState() => _DamLevelTileState();
}

class _DamLevelTileState extends State<DamLevelTile> {
  late Future<DamLevelResult> _result = _load();

  /// The department's site can be very slow, so give up after 30 seconds
  /// (whatever happens inside) and offer to try again, rather than leave
  /// the spinner running.
  Future<DamLevelResult> _load() => DamLevelsService.instance
      .levelFor(widget.station)
      .timeout(const Duration(seconds: 30), onTimeout: () => const DamLevelResult.failed(DamLevelProblem.offline))
      .catchError((Object _) => const DamLevelResult.failed(DamLevelProblem.offline));

  void _retry() => setState(() => _result = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<DamLevelResult>(
      future: _result,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Checking this week's dam level with the Department of Water and Sanitation…",
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }
        final result = snapshot.data!;
        final level = result.level;
        if (level == null) {
          if (result.problem == DamLevelProblem.notListed) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Couldn't get this week's dam level: the department's website didn't answer. "
                    'Check your connection, or try again later.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(onPressed: _retry, child: const Text('Try again')),
              ],
            ),
          );
        }
        final now = level.thisWeek;
        final others = [
          if (level.lastWeek != null) 'Last week ${level.lastWeek!.label}',
          if (level.lastYear != null) 'a year ago ${level.lastYear!.label}',
        ].join(' · ');
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dam level', style: theme.textTheme.labelLarge),
              if (now != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${now.label} full${now.latestAvailable ? ' (latest available)' : ''}',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (now.percent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
              if (others.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(others, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 4),
              InkWell(
                onTap: () => openLink(context, dwsPageUrl(widget.station.region)),
                child: Text(
                  'Department of Water and Sanitation'
                  '${level.reportDate == null ? '' : ', report of ${_date(level.reportDate!)}'}'
                  '${result.fromCache ? ' (saved copy, no connection)' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
