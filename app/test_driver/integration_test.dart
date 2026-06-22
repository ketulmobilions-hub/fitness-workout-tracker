import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

// Custom callback extracts PNG bytes from the platform channel response and
// writes each screenshot to the directory the Fastfile glob expects.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final screenshots =
        (data?['screenshots'] as List<dynamic>?) ?? const <dynamic>[];
    final dir =
        Platform.isAndroid ? 'build/android_results' : 'build/ios_results';
    for (final raw in screenshots) {
      final s = raw as Map<String, dynamic>;
      final name = s['screenshotName'] as String;
      final bytes = (s['bytes'] as List<dynamic>).cast<int>();
      final file = File('$dir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
  },
);
