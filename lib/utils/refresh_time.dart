/// Wording for "when was the town data last refreshed".
library;

/// After this long without a refresh, the app nudges the person (a dot on
/// the ⋮ menu and a highlighted "Refresh data" item).
const Duration kStaleAfter = Duration(days: 30);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Today, 13:45", "Yesterday, 08:10", "3 days ago", "9 Oct 2026", or
/// "Never" when there has been no successful refresh yet.
String describeLastRefresh(DateTime? when, DateTime now) {
  if (when == null) return 'Never';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'Today, ${_hhmm(when)}';
  if (days == 1) return 'Yesterday, ${_hhmm(when)}';
  if (days < 7) return '$days days ago';
  return '${when.day} ${_months[when.month - 1]} ${when.year}';
}

/// True when the data hasn't been refreshed for [kStaleAfter] (or ever).
bool isRefreshStale(DateTime? when, DateTime now) => when == null || now.difference(when) >= kStaleAfter;
