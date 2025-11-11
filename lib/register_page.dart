import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:entregatudo/HomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1.3.3 Convite na fluxo certo de crítica

class RegisterPage extends StatefulWidget {
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillGoogleId;
  final String? prefillPhone;
  final String? prefillUsername;

  const RegisterPage({
    super.key,
    this.prefillName,
    this.prefillEmail,
    this.prefillGoogleId,
    this.prefillPhone,
    this.prefillUsername,
  });

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
  final _inviteController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool JaMostrouCnhInv = false;
  bool JaMostrouPlaca = false;
  String? _inviteStatus;
  int _inviteValid = -1; // -1: não verificado | 0: inválido | 1: válido

  String? _inviterName;

  Future<void> _verifyInvite() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _inviteStatus = "Digite o código de convite.";
        _inviteValid = -1;
      });
      return;
    }
    try {
      final result = await API.verifyInviteCode(code);
      if (result['success'] == true) {
        setState(() {
          _inviteValid = 1;
          _inviterName = result['inviter_name'];
          _inviteStatus = "Convite válido! Captador: $_inviterName";
        });
      } else {
        setState(() {
          _inviteValid = 0;
          _inviteStatus = result['error'] ?? "Convite inválido.";
        });
      }
    } catch (e) {
      setState(() {
        _inviteValid = 0;
        _inviteStatus = "Erro ao validar convite.";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _distanciaMaximaController.text = '30';
    _aplicarPrefill(); // <- aplica params imediatamente
    _carregarFallbackDosPrefs(); // <- se não vier por params, busca prefs
  }

  // ✅ aplica imediatamente o que veio por parâmetro
  void _aplicarPrefill() {
    if (widget.prefillName?.isNotEmpty ?? false) {
      _nameController.text = widget.prefillName!;
    }
    if (widget.prefillEmail?.isNotEmpty ?? false) {
      _emailController.text = widget.prefillEmail!;
    }
    if (widget.prefillPhone?.isNotEmpty ?? false) {
      _phoneController.text = widget.prefillPhone!;
    }
    if (widget.prefillUsername?.isNotEmpty ?? false) {
      _usuarioController.text = widget.prefillUsername!;
    } else if (_usuarioController.text.isEmpty && widget.prefillEmail != null) {
      // sugestão de usuário a partir do email (antes do @)
      final at = widget.prefillEmail!.indexOf('@');
      if (at > 0)
        _usuarioController.text = widget.prefillEmail!.substring(0, at);
    }
  }

  // ✅ tenta preencher a partir dos SharedPreferences, se necessário
  Future<void> _carregarFallbackDosPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // só preenche se estiver vazio (não sobrescreve o que já veio por parâmetro)
    if (_nameController.text.isEmpty) {
      final name = prefs.getString('userName');
      if (name != null && name.isNotEmpty) _nameController.text = name;
    }
    if (_emailController.text.isEmpty) {
      final email = prefs.getString('userEmail');
      if (email != null && email.isNotEmpty) _emailController.text = email;
    }
    // opcional: sugerir usuário pelo email
    if (_usuarioController.text.isEmpty) {
      final email = _emailController.text;
      final at = email.indexOf('@');
      if (at > 0) _usuarioController.text = email.substring(0, at);
    }

    // se quiser exibir/guardar googleId pra uso interno:
    final googleId = prefs.getString('googleId'); // se o AuthService salvou
    if (googleId != null) {
      // você pode mostrar num Text abaixo do título, por exemplo:
      // setState(() => _googleId = googleId);
      // (ou apenas guardar para envio junto do cadastro)
    }
    if (mounted) setState(() {});
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
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // (Opcional) você pode mostrar o aviso de que “email/nome vieram do Google”
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
            TextFormField(
              controller: _inviteController,
              decoration: InputDecoration(
                labelText: "Código de Convite",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle),
                  onPressed: _verifyInvite,
                ),
              ),
            ),
            if (_inviteStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _inviteStatus!,
                  style: TextStyle(
                    color: _inviteValid == 1 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _enviarCadastro,
              child: const Text("Cadastrar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarCadastro() async {
    print("_enviarCadastro");
    if (_inviteValid == -1) {
      await _verifyInvite();
    }
    if (_inviteValid != 1) {
      mostrarMensagem(
        context,
        "Você precisa de um convite válido para se cadastrar.",
      );
      return;
    }
    String nome = _nameController.text.trim();
    String email = _emailController.text.trim();
    String senha = _passwordController.text;
    String cnh = _cnhController.text.trim();
    String telefone = _phoneController.text.trim();
    String placa = _placaController.text.trim().toUpperCase();
    String PIX = _pix.text.trim();
    int erroCodigo = 0;

    if (!validarNome(nome)) {
      mostrarMensagem(context, 'Por favor, insira o nome completo.');
      return;
    }
    if (!validarEmail(email)) {
      mostrarMensagem(context, 'Por favor, insira um email válido.');
      return;
    }
    if (!validarSenha(senha)) {
      mostrarMensagem(context,
          'A senha não pode ser vazia e deve ter no mínimo 6 caracteres.');
      return;
    }

    if (placa.isNotEmpty) {
      if (JaMostrouPlaca && !validarPlaca(placa)) {
        erroCodigo += 2;
      }
      if (!validarPlaca(placa)) {
        mostrarMensagem(context, 'Por favor, insira uma placa válida.');
        return;
      }
    }

    String usuario = _usuarioController.text.trim();
    String distanciaMaxStr = _distanciaMaximaController.text.trim();

    if (usuario.isEmpty) {
      mostrarMensagem(context, 'Por favor, insira o nome de usuário.');
      return;
    }

    int? distanciaMaxima = int.tryParse(distanciaMaxStr);
    if (distanciaMaxima == null ||
        distanciaMaxima < 1 ||
        distanciaMaxima > 30) {
      mostrarMensagem(context, 'Digite uma distância máxima entre 1 e 30 km.');
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
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()));
    } else {
      mostrarMensagem(
        context,
        resultado['message'],
        details: resultado['details'],
      );
    }
  }

  bool validarPlaca(String placa) {
    final regex =
        RegExp(r'^[A-Z]{3}(-\d{4}|\d{4}|\d[A-Z]\d{2})$', caseSensitive: false);
    final valida = regex.hasMatch(placa);
    if (!valida && deixaPassarCnhInv && !JaMostrouPlaca) {
      JaMostrouPlaca = true;
    }
    return valida;
  }

  bool validarNome(String nome) => nome.isNotEmpty;
  bool validarSenha(String senha) => senha.isNotEmpty && senha.length >= 6;

  bool validarEmail(String email) {
    final regex = RegExp(
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$');
    return regex.hasMatch(email);
  }

  void mostrarMensagem(BuildContext context, String mensagem,
      {String? details}) {
    if (details == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagem)));
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mensagem),
              const SizedBox(height: 10),
              const Text('Detalhes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              SelectableText(details),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: details));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Detalhes copiados para a memória')),
                );
              },
              child: const Text('Copiar detalhes para a memória'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<bool> mostrarDialogoCNHInvalida() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text("CNH Inválida"),
            content: const Text(
                "A CNH informada é inválida. Deseja continuar com o cadastro mesmo assim?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("Não")),
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text("Sim")),
            ],
          ),
        ) ??
        false;
  }
}
