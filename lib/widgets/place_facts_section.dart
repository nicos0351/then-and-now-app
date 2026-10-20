import 'package:flutter/material.dart';

import '../models/place_facts.dart';
import '../utils/links.dart';
import '../utils/town_info.dart';

/// "Facts" block for an airport, dam or pass (Plus): label/value rows and
/// tappable source links, used in the place's info sheet.
class PlaceFactsSection extends StatelessWidget {
  const PlaceFactsSection({super.key, required this.facts});

  final PlaceFacts facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Facts', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        for (final (label, value) in facts.facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        if (facts.sources.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Source:', style: theme.textTheme.bodySmall),
              for (var i = 0; i < facts.sources.length; i++)
                InkWell(
                  onTap: () => openLink(context, facts.sources[i]),
                  child: Text(
                    sourceLabel(facts.sources[i]) + (i < facts.sources.length - 1 ? ',' : ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
