import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // Certifique-se de que esta importação está correta

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '799603442315-mfortbg2p9mqgojgbfad3fh7afsvnmgf.apps.googleusercontent.com',
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      return googleUser;
    } catch (e) {
      print('Erro durante o login com Google: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Método para enviar o token de ID para o servidor
  Future<bool> authenticateWithServer(String idToken) async {
    final response = await http.post(
      Uri.parse('https://seuservidor.com/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (response.statusCode == 200) {
      // Processar a resposta do servidor
      return true;
    } else {
      // Tratar erros de autenticação
      return false;
    }
  }
}
