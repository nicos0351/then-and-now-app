import 'package:flutter/material.dart';

/// Short "how to make this sound" tips for the codes used in
/// `assets/name_stories.json` (`sounds`). Approximate guidance for
/// English and Afrikaans speakers - not a substitute for hearing a
/// first-language speaker.
const Map<String, String> soundTips = {
  'c': 'c – the "tsk" click of disapproval: pull the tip of the tongue back from the top front teeth.',
  'q': 'q – a hollow "pop", like a cork: pull the tongue sharply down from the roof of the mouth.',
  'x': 'x – the clucking click used to urge on a horse: pull the side of the tongue away from the side teeth.',
  'gc': 'gc – the c click with a "g" sound at the same time.',
  'gq': 'gq – the q "pop" click with a "g" sound at the same time. Many English speakers say a hard "k" instead.',
  'nc': 'nc – the c click with an "n" hum through the nose at the same time.',
  'nq': 'nq – the q "pop" click with an "n" hum through the nose at the same time.',
  'nx': 'nx – the x (horse) click with an "n" hum through the nose at the same time.',
  'ngc': 'ngc – the c click with an "ng" hum and a "g" at the same time.',
  'ngq': 'ngq – the q "pop" click with an "ng" hum and a "g" at the same time.',
  'rh': 'rh – like the "ch" in Scottish "loch", or the Afrikaans "g" in "goed".',
  'hl': 'hl – like the Welsh "ll": put your tongue where you would say "l", then blow air past its sides.',
  'dl': 'dl – the voiced partner of "hl": the same tongue position, with your voice on.',
  'bh': 'bh – a soft, breathy "b".',
  'ty': 'ty – close to the "ch" in "church".',
  'kg': 'kg – a "k" followed straight away by the "ch" in "loch".',
  'g_sotho': 'g – in Sepedi and Setswana, "g" sounds like the "ch" in "loch" (or a strong "h").',
  'aspirated': 'kh, ph, th – a "k", "p" or "t" with a puff of air. Not "ch", "f" or "th" as in English.',
  'm': 'm or n before another consonant – hum it as its own short beat, e.g. "m-BOM-beh-lah".',
};

/// How to read the respellings, shown from the "How to read this" link.
Future<void> showPronunciationHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return AlertDialog(
        title: const Text('How to read the pronunciation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The syllable in CAPITALS is the stressed one. In most African-language names it is the '
                'second-last syllable.\n\n'
                'ah as in "father", eh as in "bed", ee as in "see", aw as in "saw", oo as in "moon".\n\n'
                'A letter followed by a dot (c·, q·, x·) is a click. The three clicks:',
              ),
              const SizedBox(height: 8),
              for (final code in const ['c', 'q', 'x'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(soundTips[code]!, style: textTheme.bodyMedium),
                ),
              const SizedBox(height: 8),
              Text(
                'These guides are approximate. The best way to learn a name is to hear it from someone '
                'who speaks the language.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
        ],
      );
    },
  );
}
