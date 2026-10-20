import '../config/app_info.dart';
import '../models/name_story.dart';
import '../models/place_facts.dart';
import '../models/town.dart';
import 'sound_guide.dart';

/// What a line of a town's info is, so the picture can style it like the
/// town sheet does.
enum InfoKind {
  /// The town's name as the sheet's headline.
  title,

  /// "Airport · Gauteng", or just the province.
  subtitle,

  /// A small heading, e.g. "Previous name" or "Say it".
  label,

  /// A name under a [label]: the previous name or the pronunciation.
  name,

  /// Ordinary text: "Renamed in 2002", what a name means.
  body,

  /// Small print: notes, sound tips and sources.
  small,

  /// Space between the name part and the name story or facts.
  divider,

  /// One fact about an airport, dam or pass: "River: Vaal River".
  fact,
}

class InfoLine {
  const InfoLine(this.kind, this.text, {this.links = const []});

  final InfoKind kind;
  final String text;

  /// For the sources line: the full web addresses (the text shows only
  /// the site names, as the sheet does).
  final List<String> links;
}

/// A town's info exactly as the town sheet shows it to a Plus user, so
/// sharing sends what's on the screen. [showOldNames] is whether the map
/// is showing previous names (the headline then shows the previous name).
List<InfoLine> townInfo(Town town, {NameStory? story, PlaceFacts? facts, required bool showOldNames}) {
  final lines = <InfoLine>[
    InfoLine(InfoKind.title, town.displayName(showOldNames)),
    InfoLine(InfoKind.subtitle, town.kindLabel == null ? town.province : '${town.kindLabel} · ${town.province}'),
  ];
  final revealed = town.tappedName(showOldNames);
  final when = town.renamedYear == null
      ? null
      : town.reverted
          ? 'Reverted to this name in ${town.renamedYear}'
          : 'Renamed in ${town.renamedYear}';

  if (revealed != null || town.hasKnownRename) {
    lines
      ..add(InfoLine(InfoKind.label, revealed == null || !showOldNames ? 'Previous name' : 'Current name'))
      // A rename that was later reverted (e.g. Louis Trichardt).
      ..add(InfoLine(InfoKind.name, revealed ?? 'Same as today'));
    if (when != null) lines.add(InfoLine(InfoKind.body, when));
    if (town.notes != null) lines.add(InfoLine(InfoKind.small, town.notes!));
  } else {
    lines.add(InfoLine(InfoKind.body, 'No name change is on record for this ${town.kindLabel?.toLowerCase() ?? 'town'}.'));
  }

  if (revealed != null && story != null) {
    lines.add(const InfoLine(InfoKind.divider, ''));
    final say = story.say;
    if (say != null) {
      lines
        ..add(const InfoLine(InfoKind.label, 'Say it'))
        ..add(InfoLine(InfoKind.name, say));
      for (final code in story.sounds) {
        final tip = soundTips[code];
        if (tip != null) lines.add(InfoLine(InfoKind.small, tip));
      }
    }
    if (story.meaning != null) {
      lines
        ..add(InfoLine(InfoKind.label, 'About the name ${town.currentName}'))
        ..add(InfoLine(InfoKind.body, story.meaning!));
    }
    if (story.formerNameOrigin != null) {
      lines
        ..add(InfoLine(InfoKind.label, 'About the name ${town.oldName}'))
        ..add(InfoLine(InfoKind.body, story.formerNameOrigin!));
    }
    if (story.hasStory && story.sources.isNotEmpty) {
      lines.add(InfoLine(InfoKind.small, 'Source: ${story.sources.map(sourceLabel).join(', ')}',
          links: story.sources));
    }
  }

  // Airports, dams and passes: the facts, after the name history (as in
  // the sheet).
  if (facts != null) {
    lines
      ..add(const InfoLine(InfoKind.divider, ''))
      ..add(const InfoLine(InfoKind.label, 'Facts'));
    for (final (label, value) in facts.facts) {
      lines.add(InfoLine(InfoKind.fact, '$label: $value'));
    }
    if (facts.sources.isNotEmpty) {
      lines.add(InfoLine(InfoKind.small, 'Source: ${facts.sources.map(sourceLabel).join(', ')}',
          links: facts.sources));
    }
  }
  return lines;
}

/// The same info as plain text for the share message. Headings and the
/// text under them go on one line ("Previous name: Pietersburg"), and
/// sources are given as full links.
String townInfoText(List<InfoLine> lines) {
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    switch (line.kind) {
      case InfoKind.title:
      case InfoKind.subtitle:
      case InfoKind.name:
      case InfoKind.body:
      case InfoKind.fact:
        out.writeln(line.text);
      case InfoKind.small:
        out.writeln(line.links.isEmpty ? line.text : 'Source: ${line.links.join(' ')}');
      case InfoKind.divider:
        out.writeln();
      case InfoKind.label:
        final next = i + 1 < lines.length ? lines[i + 1] : null;
        if (next != null && (next.kind == InfoKind.name || next.kind == InfoKind.body)) {
          out.writeln('${line.text}: ${next.text}');
          i++;
        } else {
          out.writeln('${line.text}:');
        }
    }
    // A blank line after the place line, before the name history.
    if (line.kind == InfoKind.subtitle) out.writeln();
  }
  out
    ..writeln()
    ..write('Shared from $kAppName: ${kShareUrl.isEmpty ? kPlayStoreUrl : kShareUrl}');
  return out.toString();
}

/// "en.wikipedia.org" -> "Wikipedia", other sites -> their domain.
String sourceLabel(String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  if (host.contains('wikipedia.org')) return 'Wikipedia';
  return host.replaceFirst('www.', '');
}
