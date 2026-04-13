import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/auth_token_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/auth_repository_impl.dart';

part 'auth_providers.g.dart';

@riverpod
AuthApiClient authApiClient(Ref ref) {
  return AuthApiClient(ref.watch(dioProvider));
}

@riverpod
GoogleSignIn googleSignIn(Ref ref) {
  return GoogleSignIn(scopes: ['email']);
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    apiClient: ref.watch(authApiClientProvider),
    tokenNotifier: ref.read(authTokenProvider.notifier),
    tokenReader: () => ref.read(authTokenProvider.future),
    userDao: ref.watch(appDatabaseProvider).userDao,
    googleSignIn: ref.watch(googleSignInProvider),
  );
}
