import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_info.dart';
import '../models/name_story.dart';
import '../models/place_facts.dart';
import '../models/town.dart';
import '../utils/town_info.dart';

const _thenColour = Color(0xFF6D4C41); // matches the brown "previous names" banner
const _nowColour = Color(0xFF1565C0); // matches the blue "current" banner
const _paper = Color(0xFFF7F2E8);
const _ink = Color(0xFF263238);

/// The shareable picture of a town's info: the same lines, in the same
/// order, as the town sheet shows (see [townInfo]). 360 wide and at least
/// 450 tall (the 4:5 shape WhatsApp, Instagram and Facebook show without
/// cropping), growing for longer name stories; captured at 3x.
class TownInfoCard extends StatelessWidget {
  const TownInfoCard({super.key, required this.lines});

  final List<InfoLine> lines;

  static const double width = 360;
  static const double minHeight = 450;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Material(
          color: _paper,
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final line in lines) _line(line)],
                    ),
                  ),
                ),
                Container(
                  color: _nowColour,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.map_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kAppName,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(kAppTagline, style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(InfoLine line) {
    switch (line.kind) {
      case InfoKind.title:
        return SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(line.text,
                style: const TextStyle(fontSize: 32, height: 1.15, fontWeight: FontWeight.w800, color: _nowColour)),
          ),
        );
      case InfoKind.subtitle:
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Text(line.text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        );
      case InfoKind.divider:
        return const Divider(height: 24, color: Colors.black12);
      case InfoKind.label:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(line.text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _thenColour)),
        );
      case InfoKind.name:
        return Text(line.text, style: const TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700, color: _ink));
      case InfoKind.body:
      case InfoKind.fact:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(line.text, style: const TextStyle(fontSize: 13.5, height: 1.35, color: _ink)),
        );
      case InfoKind.small:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(line.text, style: const TextStyle(fontSize: 11.5, height: 1.3, color: Colors.black54)),
        );
    }
  }
}

/// Shows a preview of the town's info card with a Share button. The
/// picture and the message both carry exactly what the town sheet shows;
/// pass the same [showOldNames] the sheet was opened with.
Future<void> showShareCard(BuildContext context,
    {required Town town, NameStory? story, PlaceFacts? facts, bool showOldNames = false}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ShareCardDialog(town: town, story: story, facts: facts, showOldNames: showOldNames),
  );
}

class _ShareCardDialog extends StatefulWidget {
  const _ShareCardDialog({required this.town, this.story, this.facts, required this.showOldNames});
  final Town town;
  final NameStory? story;
  final PlaceFacts? facts;
  final bool showOldNames;

  @override
  State<_ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<_ShareCardDialog> {
  final _cardKey = GlobalKey();
  bool _sharing = false;
  late final List<InfoLine> _lines =
      townInfo(widget.town, story: widget.story, facts: widget.facts, showOldNames: widget.showOldNames);

  Future<void> _share(BuildContext buttonContext) async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Could not create the image');

      final slug = widget.town.currentName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final fileName = 'then-and-now-$slug.png';

      // iPad needs to know where the share popover should point.
      if (!buttonContext.mounted) return;
      final box = buttonContext.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        text: townInfoText(_lines),
        subject: widget.town.displayName(widget.showOldNames),
        sharePositionOrigin: origin,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The preview fills the dialog's width and scrolls when a long
            // name story makes it tall; the captured image is always the
            // full card at 3x (1080 pixels wide).
            Flexible(
              child: SingleChildScrollView(
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: TownInfoCard(lines: _lines),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _sharing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    onPressed: _sharing ? null : () => _share(buttonContext),
                    icon: _sharing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
