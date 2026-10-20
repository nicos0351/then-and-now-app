import 'package:flutter/material.dart';

import '../models/name_story.dart';
import '../utils/links.dart';
import '../utils/sound_guide.dart';

/// "Say it" + "About the name" block for a renamed town, used in the
/// town sheet and the "Where am I?" card.
class NameStorySection extends StatelessWidget {
  const NameStorySection({super.key, required this.story, required this.townName, required this.oldName});

  final NameStory story;
  final String townName;
  final String oldName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final say = story.say;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (say != null) ...[
          Row(
            children: [
              // No speaker-style icon here: the guide is written, and an
              // icon made it look like a button that plays the name aloud.
              Text('Say it', style: theme.textTheme.labelLarge),
              const Spacer(),
              TextButton(
                onPressed: () => showPronunciationHelp(context),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('How to read this'),
              ),
            ],
          ),
          Semantics(
            label: 'Pronunciation of $townName: $say',
            child: Text(say, style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 0.5)),
          ),
          for (final code in story.sounds)
            if (soundTips[code] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(soundTips[code]!, style: theme.textTheme.bodySmall),
              ),
          const SizedBox(height: 12),
        ],
        if (story.meaning != null) ...[
          Text('About the name $townName', style: theme.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(story.meaning!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
        ],
        if (story.formerNameOrigin != null) ...[
          Text('About the name $oldName', style: theme.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(story.formerNameOrigin!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
        ],
        if (story.hasStory && story.sources.isNotEmpty)
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Source:', style: theme.textTheme.bodySmall),
              for (var i = 0; i < story.sources.length; i++)
                InkWell(
                  onTap: () => openLink(context, story.sources[i]),
                  child: Text(
                    _label(story.sources[i]) + (i < story.sources.length - 1 ? ',' : ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// "en.wikipedia.org" -> "Wikipedia", other sites -> their domain.
  static String _label(String url) {
    final host = Uri.tryParse(url)?.host ?? url;
    if (host.contains('wikipedia.org')) return 'Wikipedia';
    return host.replaceFirst('www.', '');
  }
}
