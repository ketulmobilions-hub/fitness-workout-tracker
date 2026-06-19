import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/flutter_secure_storage_provider.dart';

part 'first_launch_provider.g.dart';

const _kOnboardingKey = 'il_onboarding_complete';

@Riverpod(keepAlive: true)
class OnboardingComplete extends _$OnboardingComplete {
  @override
  Future<bool> build() async {
    final storage = ref.read(flutterSecureStorageProvider);
    return await storage.read(key: _kOnboardingKey) == 'true';
  }

  Future<void> markComplete() async {
    await ref
        .read(flutterSecureStorageProvider)
        .write(key: _kOnboardingKey, value: 'true');
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    await ref
        .read(flutterSecureStorageProvider)
        .delete(key: _kOnboardingKey);
    state = const AsyncData(false);
  }
}
