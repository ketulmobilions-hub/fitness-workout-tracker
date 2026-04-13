/// App-wide constants.
///
/// **API base URL** — set at build time via `--dart-define`:
/// ```
/// # Development (default)
/// flutter run
///
/// # Staging / Production
/// flutter build apk --dart-define=API_BASE_URL=https://api.myapp.com/api/v1
/// ```
abstract final class AppConstants {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1', // Android emulator → host localhost
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
