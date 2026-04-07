import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

enum AuthProvider {
  emailPassword,
  google,
  apple,
  guest,
}

class AuthProviderConverter extends TypeConverter<AuthProvider, String> {
  const AuthProviderConverter();

  @override
  AuthProvider fromSql(String fromDb) {
    switch (fromDb) {
      case 'email_password':
        return AuthProvider.emailPassword;
      case 'google':
        return AuthProvider.google;
      case 'apple':
        return AuthProvider.apple;
      case 'guest':
        return AuthProvider.guest;
      default:
        debugPrint('AuthProviderConverter: unknown value "$fromDb", falling back to guest');
        return AuthProvider.guest;
    }
  }

  @override
  String toSql(AuthProvider value) {
    switch (value) {
      case AuthProvider.emailPassword:
        return 'email_password';
      case AuthProvider.google:
        return 'google';
      case AuthProvider.apple:
        return 'apple';
      case AuthProvider.guest:
        return 'guest';
    }
  }
}
