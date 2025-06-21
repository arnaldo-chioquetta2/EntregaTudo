import 'package:flutter/material.dart';
import 'package:entregatudo/HomePage.dart';
import 'package:entregatudo/api.Dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final bool deixaPassarCnhInv = true;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnhController = TextEditingController();
  final _placaController = TextEditingController();
  final _pix = TextEditingController();
  final _usuarioController = TextEditingController();
  final _distanciaMaximaController = TextEditingController();
  bool JaMostrouCnhInv = false;
  bool JaMostrouPlaca = false;

  @override
  void initState() {
    super.initState();
    _distanciaMaximaController.text = '30';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _cnhController.dispose();
    _placaController.dispose();
    _pix.dispose();
    _usuarioController.dispose();
    _distanciaMaximaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Motoboy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usuarioController,
              decoration: const InputDecoration(labelText: 'Usuário'),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome Completo'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _cnhController,
              decoration: const InputDecoration(labelText: 'CNH'),
            ),
            TextField(
              controller: _placaController,
              decoration: const InputDecoration(labelText: 'Placa'),
            ),
            TextField(
              controller: _pix,
              decoration: const InputDecoration(labelText: 'PIX'),
            ),
            TextField(
              controller: _distanciaMaximaController,
              decoration: const InputDecoration(
                labelText: 'Distância Máxima (km)',
                helperText: 'Valor entre 1 e 30',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String nome = _nameController.text;
                String email = _emailController.text;
                String senha = _passwordController.text;
                String cnh = _cnhController.text;
                String telefone = _phoneController.text;
                String placa = _placaController.text;
                String PIX = _pix.text;
                int erroCodigo = 0;
                if (!validarNome(nome)) {
                  mostrarMensagem(
                      context, 'Por favor, insira o nome completo.');
                  return;
                }
                if (!validarEmail(email)) {
                  mostrarMensagem(
                      context, 'Por favor, insira um email válido.');
                  return;
                }
                if (!validarSenha(senha)) {
                  mostrarMensagem(context,
                      'A senha não pode ser vazia e deve ter no mínimo 6 caracteres.');
                  return;
                }

                // if (JaMostrouCnhInv == false) {
                //   if (!await validarEProcessarCnh()) return;
                // }
                // if (JaMostrouCnhInv && !await validarCNH(cnh)) {
                //   erroCodigo += 1;
                // }

                if (placa.isNotEmpty) {
                  if (JaMostrouPlaca && !validarPlaca(placa)) {
                    erroCodigo += 2;
                  }
                  if (!validarPlaca(placa)) {
                    mostrarMensagem(
                        context, 'Por favor, insira uma placa válida.');
                    return;
                  }
                }

                String usuario = _usuarioController.text.trim();
                String distanciaMaxStr = _distanciaMaximaController.text.trim();

                if (usuario.isEmpty) {
                  mostrarMensagem(
                      context, 'Por favor, insira o nome de usuário.');
                  return;
                }

                int? distanciaMaxima = int.tryParse(distanciaMaxStr);
                if (distanciaMaxima == null ||
                    distanciaMaxima < 1 ||
                    distanciaMaxima > 30) {
                  mostrarMensagem(
                      context, 'Digite uma distância máxima entre 1 e 30 km.');
                  return;
                }

                final resultado = await API.registerUser(
                  nome,
                  usuario,
                  email,
                  senha,
                  telefone,
                  cnh,
                  placa,
                  PIX,
                  erroCodigo,
                  distanciaMaxima,
                );

                if (resultado['success']) {
                  mostrarMensagem(context, 'Cadastro bem-sucedido');
                  print('Cadastro bem-sucedido');
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => const HomePage()));
                } else {
                  mostrarMensagem(context, resultado['message']);
                }
              },
              child: const Text("Cadastrar"),
            ),
          ],
        ),
      ),
    );
  }

  bool validarPlaca(String placa) {
    RegExp regex = RegExp(
      r'^[A-Z]{3}(-\d{4}|\d{4}|\d[A-Z]\d{2})$',
      caseSensitive: false,
    );

    bool valida = regex.hasMatch(placa);
    if (!valida && deixaPassarCnhInv && !JaMostrouPlaca) {
      JaMostrouPlaca = true;
    }
    return valida;
  }

  bool validarNome(String nome) {
    return nome.isNotEmpty;
  }

  bool validarSenha(String senha) {
    return senha.isNotEmpty && senha.length >= 6;
  }

  bool validarEmail(String email) {
    Pattern pattern =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regex = RegExp(pattern.toString());
    return regex.hasMatch(email);
  }

  void mostrarMensagem(BuildContext context, String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  // Future<bool> validarCNH(String cnh) async {
  //   String cnhSemFormatacao = cnh.replaceAll(RegExp(r'\D'), '');
  //   if (cnhSemFormatacao.length != 11 || cnhSemFormatacao == "00000000000") {
  //     return false;
  //   }
  //   int soma = 0;
  //   for (int i = 0; i < 9; i++) {
  //     soma += int.parse(cnhSemFormatacao[i]) * (9 - i);
  //   }
  //   int d1 = soma % 11;
  //   d1 = d1 < 10 ? d1 : 0;
  //   soma = 0;
  //   for (int i = 0; i < 9; i++) {
  //     soma += int.parse(cnhSemFormatacao[i]) * (10 - i);
  //   }
  //   soma += d1 * 2;
  //   int d2 = soma % 11;
  //   d2 = d2 < 10 ? d2 : 0;
  //   bool valido = d1 == int.parse(cnhSemFormatacao[9]) &&
  //       d2 == int.parse(cnhSemFormatacao[10]);
  //   return valido;
  // }

  Future<bool> mostrarDialogoCNHInvalida() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false, // O usuário precisa selecionar uma opção
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("CNH Inválida"),
              content: const Text(
                  "A CNH informada é inválida. Deseja continuar com o cadastro mesmo assim?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(false), // Retorna false
                  child: const Text("Não"),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(true), // Retorna true
                  child: const Text("Sim"),
                ),
              ],
            );
          },
        ) ??
        false; // Garante que um valor booleano seja retornado mesmo se o diálogo for fechado de outra forma
  }
}
