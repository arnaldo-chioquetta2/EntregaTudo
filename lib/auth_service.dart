import 'dart:convert';
import 'package:entregatudo/api.dart';
import 'package:http/http.dart' as http;
// import 'package:google_sign_in/google_sign_in.dart'; // 🔸 Desativado temporariamente
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthResult {
  final bool success;
  final String? message;
  final int? userId;
  final String? accessToken;
  final String? refreshToken;
  final bool? isNewUser;
  final int? queryId;
  final String? email;
  final String? displayName;
  final String? googleId;

  AuthResult({
    required this.success,
    this.message,
    this.userId,
    this.accessToken,
    this.refreshToken,
    this.isNewUser,
    this.queryId,
    this.email,
    this.displayName,
    this.googleId,
  });
}

class AuthService {
  static const _webClientId =
      '1092224573691-fo0hh8apcun2mllc9bk26s92330q5kus.apps.googleusercontent.com'; // 🔸 Mantido apenas como referência

  // 🔹 Desativado: inicialização do Google Sign-In
  // final GoogleSignIn _googleSignIn = GoogleSignIn(
  //   clientId: kIsWeb ? _webClientId : null,
  //   scopes: const <String>[
  //     'email',
  //     'profile',
  //     'openid',
  //   ],
  // );

  final _secure = const FlutterSecureStorage();
  int? _lastQueryId;
  int? get lastQueryId => _lastQueryId;

  // 🔹 Stub temporário: login Google desativado
  Future<AuthResult> signInWithGoogle() async {
    print('⚠️ Login Google desativado temporariamente');
    return AuthResult(
      success: false,
      message: 'Login Google desativado nesta versão.',
    );
  }

  // 🔹 Stub temporário: polling de credenciais (mantido ativo pois usado por backend)
  Future<AuthResult> trazCredenciais({
    int? userIdForQuery,
    Duration interval = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 20),
  }) async {
    print('⚠️ Polling de credenciais desativado temporariamente (Google).');
    return AuthResult(
      success: false,
      message: 'Função Google desativada.',
    );
  }

  // 🔹 Stub temporário: signOut do Google
  Future<void> signOut() async {
    print('⚠️ SignOut Google desativado temporariamente');
    await _secure.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('idUser');
  }

  Future<void> _persistSession({
    required int userId,
    String? accessToken,
    String? refreshToken,
    String? email,
    String? displayName,
    String? photoUrl,
    String? googleId,
  }) async {
    print('[Auth] _persistSession START (userId=$userId)');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('idUser', userId);

      if (email != null && email.isNotEmpty) {
        await prefs.setString('userEmail', email);
      }
      if (displayName != null && displayName.isNotEmpty) {
        await prefs.setString('userName', displayName);
      }
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await prefs.setString('userAvatar', photoUrl);
      }
      if (googleId != null && googleId.isNotEmpty) {
        await prefs.setString('googleId', googleId);
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        await _secure.write(key: 'access_token', value: accessToken);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _secure.write(key: 'refresh_token', value: refreshToken);
      }

      print('[Auth] _persistSession DONE');
    } catch (e) {
      print('[Auth] _persistSession ERROR: $e');
    }
  }

  // 🔹 Stub temporário: tentativa de login silencioso com Google
  Future<AuthResult> trySilentGoogleLogin() async {
    print('⚠️ Silent Login Google desativado temporariamente');
    return AuthResult(
      success: false,
      message: 'Login Google desativado nesta versão.',
    );
  }
}
