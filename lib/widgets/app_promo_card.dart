import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_info.dart';

const _thenColour = Color(0xFF8D6E63); // the icon's brown (then)
const _nowColour = Color(0xFF1976D2); // the icon's blue (now)
const _paper = Color(0xFFF6EFE3); // the icon's cream background
const _ink = Color(0xFF263238);

const _iconAsset = 'assets/icon/app_icon.png';

/// The "Share this app" picture: the app icon, name, what it does, an
/// example rename, and where to find it. Laid out at 360 x 450 and captured
/// at 3x, giving a 1080 x 1350 image (the 4:5 shape WhatsApp, Instagram and
/// Facebook show without cropping).
class AppPromoCard extends StatelessWidget {
  const AppPromoCard({super.key});

  static const Size size = Size(360, 450);

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Material(
        color: _paper,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // A shadow, so the icon (cream, like the card) reads as an
                  // app icon.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(_iconAsset, width: 60, height: 60),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Then & Now',
                            style: TextStyle(fontSize: 28, height: 1.05, fontWeight: FontWeight.w800, color: _ink)),
                        Text('SA Place Names', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _nowColour)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "South Africa's old and new place names on one map.",
                style: TextStyle(fontSize: 15, height: 1.3, color: _ink),
              ),
              const SizedBox(height: 12),
              // An example, so people see straight away what the app is about.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Row(
                  children: [
                    _Then('THEN', 'Pietersburg', _thenColour),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.black38),
                    ),
                    _Then('NOW', 'Polokwane', _nowColour),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _Feature(Icons.map_outlined, '1,000 towns plus every airport, dam and pass'),
              const _Feature(Icons.history, "Flip between previous and today's names"),
              const _Feature(Icons.timeline, 'Watch the names change on the timeline'),
              const _Feature(Icons.my_location, '"Where am I?" tells your town\'s story'),
              const Spacer(),
              const Divider(height: 16, color: Colors.black12),
              Text(
                kOnAppStore ? 'Free on Google Play and the App Store' : 'Free on Google Play',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 2),
              const Text(
                'Search for "$kStoreSearchText"',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Then extends StatelessWidget {
  const _Then(this.label, this.name, this.colour);
  final String label;
  final String name;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: colour)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colour)),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _nowColour),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.25, color: _ink))),
        ],
      ),
    );
  }
}

/// The message that goes with the picture: what the app does and where
/// to get it on each phone. Links are added when they're known.
String appPromoText() {
  final buffer = StringBuffer()
    ..writeln("Have a look at $kAppName - South Africa's old and new place names on one map.")
    ..writeln()
    ..writeln('• Flip the whole map between previous and current names')
    ..writeln('• Tap a town to see when it was renamed')
    ..writeln('• Slide through the years on the timeline')
    ..writeln('• "Where am I?" finds your town and its story')
    ..writeln()
    ..writeln("It's free to download:")
    ..writeln('Android: open Google Play and search for "$kStoreSearchText", or go to $kPlayStoreUrl');
  if (kOnAppStore) {
    final link = kAppStoreUrl;
    buffer.writeln(link.isEmpty
        ? 'iPhone: open the App Store and search for "$kStoreSearchText"'
        : 'iPhone: open the App Store and search for "$kStoreSearchText", or go to $link');
  }
  return buffer.toString().trimRight();
}

/// "Share this app": shows the picture with a Share button.
Future<void> showAppPromo(BuildContext context) {
  return showDialog<void>(context: context, builder: (context) => const _AppPromoDialog());
}

class _AppPromoDialog extends StatefulWidget {
  const _AppPromoDialog();

  @override
  State<_AppPromoDialog> createState() => _AppPromoDialogState();
}

class _AppPromoDialogState extends State<_AppPromoDialog> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Make sure the icon is decoded before anyone can tap Share, so it's
    // never missing from the picture.
    precacheImage(const AssetImage(_iconAsset), context);
  }

  Future<void> _share(BuildContext buttonContext) async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Could not create the image');

      const fileName = 'then-and-now-app.png';

      // iPad needs to know where the share popover should point.
      if (!buttonContext.mounted) return;
      final box = buttonContext.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
        fileNameOverrides: const [fileName],
        text: appPromoText(),
        subject: kAppName,
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
            Text('Share $kAppShortName', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Sends this picture with a short description and where to find the app.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // The preview is scaled to fit the screen; the captured image is
            // always the full 1080 x 1350.
            Flexible(
              child: FittedBox(
                child: RepaintBoundary(key: _cardKey, child: const AppPromoCard()),
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
