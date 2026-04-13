import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers/auth_token_provider.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApiClient apiClient,
    required AuthTokenNotifier tokenNotifier,
    required Future<AuthToken?> Function() tokenReader,
    required UserDao userDao,
    required GoogleSignIn googleSignIn,
  })  : _apiClient = apiClient,
        _tokenNotifier = tokenNotifier,
        _tokenReader = tokenReader,
        _userDao = userDao,
        _googleSignIn = googleSignIn;

  final AuthApiClient _apiClient;
  final AuthTokenNotifier _tokenNotifier;
  final Future<AuthToken?> Function() _tokenReader;
  final UserDao _userDao;
  final GoogleSignIn _googleSignIn;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final envelope = await _apiClient.login(
      LoginRequestDto(email: email, password: password),
    );
    return _handleAuthResponse(
      envelope.data,
      provider: AuthProvider.emailPassword,
      isGuest: false,
    );
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final envelope = await _apiClient.register(
      RegisterRequestDto(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
    return _handleAuthResponse(
      envelope.data,
      provider: AuthProvider.emailPassword,
      isGuest: false,
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw const AppException.cancelled();
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AppException.unknown(
        message: 'Google sign-in did not return an ID token.',
      );
    }
    final envelope = await _apiClient.googleSignIn(
      GoogleSignInRequestDto(idToken: idToken),
    );
    return _handleAuthResponse(
      envelope.data,
      provider: AuthProvider.google,
      isGuest: false,
    );
  }

  @override
  Future<AuthUser> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final displayName = [
      credential.givenName,
      credential.familyName,
    ].where((s) => s != null && s.isNotEmpty).join(' ');

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw const AppException.unknown(
        message: 'Apple sign-in did not return an identity token.',
      );
    }

    final envelope = await _apiClient.appleSignIn(
      AppleSignInRequestDto(
        identityToken: identityToken,
        displayName: displayName.isEmpty ? null : displayName,
      ),
    );
    return _handleAuthResponse(
      envelope.data,
      provider: AuthProvider.apple,
      isGuest: false,
    );
  }

  @override
  Future<AuthUser> signInAsGuest() async {
    final envelope = await _apiClient.guestSignIn();
    return _handleAuthResponse(
      envelope.data,
      provider: AuthProvider.guest,
      isGuest: true,
    );
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _apiClient.forgotPassword(ForgotPasswordRequestDto(email: email));
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _apiClient.resetPassword(
      ResetPasswordRequestDto(token: token, newPassword: newPassword),
    );
  }

  @override
  Future<void> logout() async {
    await _tokenNotifier.clearTokens();
    await _googleSignIn.signOut().catchError((_) => null);
  }

  @override
  Future<void> refreshTokens() async {
    final current = await _tokenReader();
    if (current?.refreshToken == null) {
      throw const AppException.unauthorized(
        message: 'No refresh token available.',
      );
    }
    final envelope = await _apiClient.refreshToken({
      'refreshToken': current!.refreshToken!,
    });
    await _tokenNotifier.setTokens(
      AuthToken(
        accessToken: envelope.data.accessToken,
        refreshToken: envelope.data.refreshToken,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<AuthUser> _handleAuthResponse(
    AuthResponseDto dto, {
    required AuthProvider provider,
    required bool isGuest,
  }) async {
    await _tokenNotifier.setTokens(
      AuthToken(
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
      ),
    );
    final displayName = await _persistUser(
      dto.user,
      provider: provider,
      isGuest: isGuest,
    );
    return _mapUser(dto.user, displayName: displayName, isGuest: isGuest);
  }

  Future<String> _persistUser(
    AuthUserDto dto, {
    required AuthProvider provider,
    required bool isGuest,
  }) async {
    // Guests have no email from the server; use a stable placeholder so the
    // non-nullable unique Drift column constraint is satisfied.
    final effectiveEmail = dto.email ?? 'guest:${dto.id}';

    // Apple only sends givenName/familyName on the first sign-in. On every
    // subsequent sign-in the server returns null for displayName. To avoid
    // overwriting the name the user chose during initial sign-in, fall back
    // to the existing DB value when the server omits the name.
    final String displayName;
    if (dto.displayName != null) {
      displayName = dto.displayName!;
    } else if (isGuest) {
      displayName = 'Guest';
    } else {
      final existing = await _userDao.getUser(dto.id);
      displayName = existing?.displayName ?? 'User';
    }

    await _userDao.upsertUser(
      UsersCompanion.insert(
        id: dto.id,
        email: effectiveEmail,
        displayName: displayName,
        authProvider: provider,
        isGuest: Value(isGuest),
      ),
    );
    return displayName;
  }

  AuthUser _mapUser(
    AuthUserDto dto, {
    required String displayName,
    required bool isGuest,
  }) {
    return AuthUser(
      id: dto.id,
      email: dto.email,
      displayName: displayName,
      isGuest: isGuest,
    );
  }
}
