import 'dart:convert';
import 'package:entregatudo/api.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
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

  AuthResult({
    required this.success,
    this.message,
    this.userId,
    this.accessToken,
    this.refreshToken,
    this.isNewUser,
    this.queryId, // <--
  });
}

class AuthService {
  static const _webClientId =
      '1092224573691-fo0hh8apcun2mllc9bk26s92330q5kus.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
    scopes: <String>['email', 'profile'],
  );

  final _secure = const FlutterSecureStorage();
  int? _lastQueryId;

  /// Dispara o fluxo de login com Google:
  /// 1) pede ao backend o próximo ID de usuário (next-user-id) para usar na query ?ID=
  /// 2) abre o prompt do Google, obtém o idToken
  /// 3) envia o idToken ao backend no callback do site, junto do ?ID= obtido
  /// 4) trata a resposta imediata do backend:
  ///    - se já vier user_id/tokens, persiste e termina (sucesso);
  ///    - se vier apenas "processing", devolve sucesso parcial (app fará polling com trazCredenciais);
  ///    - se vier erro, encerra com mensagem apropriada.

  Future<AuthResult> signInWithGoogle() async {
    try {
      print('[Auth] signInWithGoogle() INÍCIO');

      final int? maybeId = await API.nextUserId();
      print('[Auth] nextUserId -> $maybeId');

      if (maybeId == null) {
        print('[Auth] nextUserId = null (ABORTAR)');
        return AuthResult(success: false, message: 'Falha no next-user-id');
      }

      final int queryId = maybeId;
      _lastQueryId = queryId;
      print('[Auth] queryId definido = $_lastQueryId');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('[Auth] googleUser = ${googleUser?.email ?? '(null)'}');
      if (googleUser == null) {
        print('[Auth] Usuário cancelou o login Google');
        return AuthResult(
            success: false, message: 'Cancelado', queryId: queryId);
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      print('[Auth] idToken isNull? ${idToken == null}');
      if (idToken == null) {
        await _googleSignIn.signOut();
        print('[Auth] idToken nulo -> signOut() e aborta');
        return AuthResult(
            success: false, message: 'idToken ausente', queryId: queryId);
      }

      print('[Auth] Chamando API.googleLoginInit(ID=$queryId)');
      final init =
          await API.googleLoginInit(idToken: idToken, userIdForQuery: queryId);
      print('[Auth] googleLoginInit => $init');

      final ok = init['success'] == true;

      if (ok && init.containsKey('user_id')) {
        print('[Auth] Resposta já contém user_id (finalização direta)');
        final int? userId = (init['user_id'] is int)
            ? init['user_id'] as int
            : int.tryParse('${init['user_id']}');
        final String? access = init['access_token'] as String?;
        final String? refresh = init['refresh_token'] as String?;

        if (userId != null) {
          print('[Auth] Persistindo sessão userId=$userId');
          await _persistSession(
            userId: userId,
            accessToken: access,
            refreshToken: refresh,
            email: googleUser.email,
            displayName: googleUser.displayName,
            photoUrl: googleUser.photoUrl,
          );
        }

        return AuthResult(
          success: true,
          message: init['message']?.toString() ?? 'ok',
          userId: userId,
          accessToken: access,
          refreshToken: refresh,
          isNewUser: init['is_new_user'] == true,
          queryId: queryId,
        );
      }

      if (ok) {
        print('[Auth] Backend respondeu success, mas sem user_id (PROCESSING)');
        return AuthResult(
          success: true,
          message: init['message']?.toString() ?? 'processing',
          queryId: queryId,
        );
      }

      print('[Auth] Falha no init: ${init['message']}');
      return AuthResult(
        success: false,
        message: init['message']?.toString() ?? 'Falha ao iniciar login Google',
        queryId: queryId,
      );
    } catch (e) {
      print('[Auth] EXCEPTION em signInWithGoogle: $e');
      return AuthResult(success: false, message: 'Erro: $e');
    }
  }

  Future<AuthResult> trazCredenciais({
    int? userIdForQuery,
    Duration interval = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 20),

    // MOCK
    bool mock = false,
    String? mockEmail,
    String? mockGoogleId,
    String? mockDisplayName,
    bool mockIsNewUser = false,
  }) async {
    final start = DateTime.now();
    final int queryId = userIdForQuery ?? (_lastQueryId ?? 999999);

    print('[Auth] trazCredenciais() INÍCIO | queryId=$queryId | mock=$mock');

    // --- MODO MOCK: SEM consultar servidor, espera 10 ciclos ---
    if (mock) {
      for (int i = 1; i <= 5; i++) {
        print(
            '[Auth][MOCK] tentativa $i/10 (interval=${interval.inMilliseconds}ms)');
        await Future.delayed(interval);
      }

      final int fakeUserId = queryId;
      print(
          '[Auth][MOCK] 10/10 atingido. Persistindo sessão fakeUserId=$fakeUserId');

      await _persistSession(
        userId: fakeUserId,
        email: mockEmail ?? 'xeviousbr@gmail.com',
        displayName: mockDisplayName ?? 'Arnaldo (Mock)',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'googleId', mockGoogleId ?? '0108000582172014674272');

      print('[Auth][MOCK] Retornando sucesso isNewUser=$mockIsNewUser');
      return AuthResult(
        success: true,
        message: 'mock: login concluído',
        userId: fakeUserId,
        isNewUser: mockIsNewUser, // false => Home; true => cadastro
        accessToken: null,
        refreshToken: null,
        queryId: queryId,
      );
    }

    // --- FLUXO REAL: consulta servidor ---
    while (true) {
      final elapsed = DateTime.now().difference(start);
      if (elapsed >= timeout) {
        print('[Auth] TIMEOUT ($elapsed)');
        return AuthResult(
          success: false,
          message: 'Tempo esgotado aguardando confirmação do login.',
          queryId: queryId,
        );
      }

      print('[Auth] Chamando API.googleLoginStatus(ID=$queryId)');
      final status = await API.googleLoginStatus(userIdForQuery: queryId);
      print('[Auth] status => $status');

      final done = status['done'] == true;
      if (!done) {
        print(
            '[Auth] done=false -> aguardando ${interval.inMilliseconds}ms...');
        await Future.delayed(interval);
        continue;
      }

      final success = status['success'] == true;
      final message = status['message']?.toString();
      print('[Auth] done=true | success=$success | message=$message');

      if (!success) {
        return AuthResult(
          success: false,
          message: message ?? 'Falha no login.',
          queryId: queryId,
        );
      }

      final int? userId = (status['user_id'] is int)
          ? status['user_id'] as int
          : int.tryParse('${status['user_id']}');
      final bool isNew = status['is_new_user'] == true;
      final String? access = status['access_token'] as String?;
      final String? refresh = status['refresh_token'] as String?;

      print('[Auth] userId=$userId | isNewUser=$isNew');

      if (userId == null) {
        print('[Auth] ERRO: user_id ausente');
        return AuthResult(
          success: false,
          message: 'Resposta inválida do servidor: user_id ausente.',
          queryId: queryId,
        );
      }

      await _persistSession(
        userId: userId,
        accessToken: access,
        refreshToken: refresh,
      );
      print('[Auth] Sessão persistida (userId=$userId)');

      return AuthResult(
        success: true,
        message: message ?? 'ok',
        userId: userId,
        accessToken: access,
        refreshToken: refresh,
        isNewUser: isNew,
        queryId: queryId,
      );
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('idUser', userId);
    if (accessToken != null)
      await _secure.write(key: 'access_token', value: accessToken);
    if (refreshToken != null)
      await _secure.write(key: 'refresh_token', value: refreshToken);
    if (email != null) await prefs.setString('userEmail', email);
    if (displayName != null) await prefs.setString('userName', displayName);
    if (photoUrl != null) await prefs.setString('userAvatar', photoUrl);
  }
}
