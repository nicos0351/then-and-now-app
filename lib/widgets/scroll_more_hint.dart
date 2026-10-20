import 'package:flutter/material.dart';

/// A scrolling column that shows a "More below" marker (and a visible
/// scroll bar) while there's more content further down, so people know to
/// scroll. Tapping the marker scrolls down; it goes away at the end.
class ScrollWithMoreHint extends StatefulWidget {
  const ScrollWithMoreHint({super.key, required this.child, this.padding = EdgeInsets.zero, this.fadeColor});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// The background the content fades into under the marker (defaults to
  /// a bottom sheet's colour).
  final Color? fadeColor;

  @override
  State<ScrollWithMoreHint> createState() => _ScrollWithMoreHintState();
}

class _ScrollWithMoreHintState extends State<ScrollWithMoreHint> {
  final _controller = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final more = p.maxScrollExtent - p.pixels > 8;
    if (more != _more) setState(() => _more = more);
  }

  void _scrollDown() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    _controller.animateTo(
      (p.pixels + p.viewportDimension * 0.7).clamp(0.0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fade = widget.fadeColor ?? scheme.surfaceContainerLow;
    return Stack(
      children: [
        // Content can change height (e.g. a dam level arriving), so check
        // again whenever the scroll area's size changes.
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _update());
            return false;
          },
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: _more,
            child: SingleChildScrollView(
              controller: _controller,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
        if (_more)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _scrollDown,
              child: Container(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fade.withValues(alpha: 0), fade],
                  ),
                ),
                alignment: Alignment.center,
                child: Material(
                  color: scheme.primaryContainer,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('More below',
                            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 20, color: scheme.onPrimaryContainer),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
