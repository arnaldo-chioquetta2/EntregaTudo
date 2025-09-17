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
      '1092224573691-fo0hh8apcun2mllc9bk26s92330q5kus.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
    scopes: const <String>[
      'email',
      'profile',
      'openid',
    ],
  );

  final _secure = const FlutterSecureStorage();
  int? _lastQueryId;
  int? get lastQueryId => _lastQueryId;

  /// Dispara o fluxo de login com Google:
  /// 1) pede ao backend o próximo ID de usuário (next-user-id) para usar na query ?ID=
  /// 2) abre o prompt do Google, obtém o idToken
  /// 3) envia o idToken ao backend no callback do site, junto do ?ID= obtido
  /// 4) trata a resposta imediata do backend:
  ///    - se já vier user_id/tokens, persiste e termina (sucesso);
  ///    - se vier apenas "processing", devolve sucesso parcial (app fará polling com trazCredenciais);
  ///    - se vier erro, encerra com mensagem apropriada.

  Future<AuthResult> signInWithGoogle() async {
    print('Versão 1');

    try {
      print('[Auth] signInWithGoogle() INÍCIO');

      // (1) Pede ao backend o próximo ID para amarrar o fluxo (?ID=...)
      final int? maybeId = await API.nextUserId();
      print('[Auth] nextUserId -> $maybeId');

      if (maybeId == null) {
        return AuthResult(
          success: false,
          message:
              'Não foi possível obter o próximo ID de usuário (next-user-id).',
        );
      }

      // (1.b) Define non-nullable e guarda pra polling depois
      final int queryId = maybeId;
      _lastQueryId = queryId;
      print('[Auth] queryId definido = $queryId');

      // (2) Abre o fluxo de seleção de conta Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('[Auth] googleUser == null (cancelado pelo usuário)');
        return AuthResult(
          success: false,
          message: 'Login cancelado pelo usuário.',
          queryId: queryId,
        );
      }

      // (2.a) Tokens do Google
      final googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      print('[Auth] idToken: ${idToken == null ? 'NULO' : 'obtido'}');

      final String? accessToken = googleAuth.accessToken;
      print('[Auth] accessToken: ${accessToken == null ? 'NULO' : 'obtido'}');

      if (idToken == null && accessToken == null) {
        print('idToken == null');
        await _googleSignIn.signOut();
        return AuthResult(
          success: false,
          message:
              'Não foi possível obter credenciais do Google (idToken/accessToken).',
          queryId: queryId,
        );
      }

      // if (idToken == null) {
      //   await _googleSignIn.signOut();
      //   return AuthResult(
      //     success: false,
      //     message: 'Não foi possível obter o idToken do Google.',
      //     queryId: queryId,
      //   );
      // }

      // (2.b) Salva dados de perfil para prefill (mesmo antes de concluir no server)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', googleUser.email);
        if (googleUser.displayName != null) {
          await prefs.setString('userName', googleUser.displayName!);
        }
        if (googleUser.photoUrl != null) {
          await prefs.setString('userAvatar', googleUser.photoUrl!);
        }
        // guardar googleId para uso interno (se quiser usar no app)
        // (RegisterPage já tenta ler 'googleId', então é útil salvar)
        if (googleUser.id.isNotEmpty) {
          await prefs.setString('googleId', googleUser.id);
        }
      } catch (e) {
        print('[Auth] aviso: falhou ao salvar prefill local: $e');
      }

      // (3) Chama o callback do server com ?ID=<queryId> + { idToken }
      print('[Auth] chamando API.googleLoginInit (queryId=$queryId)');

      final Map<String, dynamic> init = await API.googleLoginInit(
        idToken: idToken,
        accessToken: accessToken,
        userIdForQuery: queryId,
      );

      // final Map<String, dynamic> init = await API.googleLoginInit(
      //   idToken: idToken,
      //   accessToken: accessToken,
      //   userIdForQuery: queryId,
      // );

      print('[Auth] googleLoginInit retorno: $init');

      final bool ok = init['success'] == true;

      // (4) Server já finalizou e devolveu user_id (e possivelmente tokens)
      if (ok && init.containsKey('user_id')) {
        final int? userId = (init['user_id'] is int)
            ? init['user_id'] as int
            : int.tryParse('${init['user_id']}');

        final String? access = init['access_token'] as String?;
        final String? refresh = init['refresh_token'] as String?;

        if (userId != null) {
          await _persistSession(
            userId: userId,
            accessToken: access,
            refreshToken: refresh,
            email: googleUser.email,
            displayName: googleUser.displayName,
            photoUrl: googleUser.photoUrl,
          );
        }

        print('[Auth] sucesso imediato. is_new_user=${init['is_new_user']}');
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

      // (5) Server sinalizou apenas "processing" → App deve fazer polling em /api/login/status
      if (ok) {
        print('[Auth] processamento em andamento (usar trazCredenciais)');
        return AuthResult(
          success: true,
          message: init['message']?.toString() ?? 'processing',
          queryId: queryId,
        );
      }

      // (6) Erro imediato do server
      print('[Auth] falha imediata: ${init['message']}');
      return AuthResult(
        success: false,
        message: init['message']?.toString() ?? 'Falha ao iniciar login Google',
        queryId: queryId,
      );
    } catch (e) {
      print('[Auth] EXCEPTION signInWithGoogle: $e');
      return AuthResult(
        success: false,
        message: 'Erro durante o login: $e',
      );
    }
  }

  Future<AuthResult> trazCredenciais({
    int? userIdForQuery, // agora opcional
    Duration interval = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // Usa o mesmo ID que foi usado no callback
    final qid = userIdForQuery ?? _lastQueryId;
    if (qid == null) {
      return AuthResult(
          success: false, message: 'queryId ausente para polling.');
    }

    final started = DateTime.now();
    var attempt = 0;

    while (true) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed >= timeout) {
        print(
            '[Auth][poll] TIMEOUT após ${elapsed.inMilliseconds}ms (tries=$attempt)');
        return AuthResult(
          success: false,
          message: 'Tempo esgotado aguardando confirmação do login.',
        );
      }

      attempt++;
      print('[Auth][poll] try=$attempt qid=$qid GET /api/login/status?ID=$qid');

      final status = await API.googleLoginStatus(userIdForQuery: qid);
      print('[Auth][poll] status=$status');

      final done = status['done'] == true;
      if (!done) {
        await Future.delayed(interval);
        continue;
      }

      final success = status['success'] == true;
      final message = status['message']?.toString();

      if (!success) {
        return AuthResult(
            success: false, message: message ?? 'Falha no login.');
      }

      final int? userId = (status['user_id'] is int)
          ? status['user_id'] as int
          : int.tryParse('${status['user_id']}');
      final bool isNew = status['is_new_user'] == true;
      final String? access = status['access_token'] as String?;
      final String? refresh = status['refresh_token'] as String?;

      if (userId == null) {
        return AuthResult(
          success: false,
          message: 'Resposta inválida do servidor: user_id ausente.',
        );
      }

      await _persistSession(
        userId: userId,
        accessToken: access,
        refreshToken: refresh,
      );

      return AuthResult(
        success: true,
        message: message ?? 'ok',
        userId: userId,
        accessToken: access,
        refreshToken: refresh,
        isNewUser: isNew,
        queryId: qid,
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
    String? googleId, // <-- novo
  }) async {
    print('[Auth] _persistSession START (userId=$userId)');

    try {
      // SharedPreferences: dados “não sensíveis”
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

      // FlutterSecureStorage: dados sensíveis
      if (accessToken != null && accessToken.isNotEmpty) {
        await _secure.write(key: 'access_token', value: accessToken);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _secure.write(key: 'refresh_token', value: refreshToken);
      }

      print('[Auth] _persistSession DONE');
    } catch (e) {
      print('[Auth] _persistSession ERROR: $e');
      // não lança de novo para não quebrar o fluxo de login
    }
  }
}
