import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/services/app_update_service.dart';

void main() {
  test('recognises Google Play saying the copy is not from Google Play', () {
    expect(AppUpdateService.isNotFromPlayError('Install Error(-10): The app is not owned by any user on this device.'), isTrue);
    expect(AppUpdateService.isNotFromPlayError('Install Error(-6): The download/install is not allowed'), isTrue);
    expect(AppUpdateService.isNotFromPlayError('Install Error(-9): The Play Store app is unavailable'), isFalse);
    expect(AppUpdateService.isNotFromPlayError(null), isFalse);
  });

  test('every outcome of "Check for updates" says something sensible', () {
    for (final outcome in UpdateCheckOutcome.values) {
      final message = AppUpdateService.messageFor(outcome);
      if (outcome == UpdateCheckOutcome.readyToInstall) {
        expect(message, isNull, reason: 'the Restart message says it');
      } else {
        expect(message, isNotEmpty, reason: outcome.name);
      }
    }
    expect(AppUpdateService.messageFor(UpdateCheckOutcome.upToDate), contains('latest version'));
    expect(AppUpdateService.messageFor(UpdateCheckOutcome.notFromPlay), contains('Google Play'));
  });
}
