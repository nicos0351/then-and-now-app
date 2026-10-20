import 'package:flutter/material.dart';

import '../config/app_info.dart';

/// Shown in place of a Plus-only feature for free users: says what's
/// there and offers the upgrade. Tapping calls [onUnlock].
class PlusTeaser extends StatelessWidget {
  const PlusTeaser({super.key, required this.title, required this.text, required this.onUnlock});

  final String title;
  final String text;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Get $kPlusName'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
