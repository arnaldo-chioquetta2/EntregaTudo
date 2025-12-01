import 'dart:convert';
import 'dart:ui';
import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:entregatudo/HomePage.dart';
import 'package:entregatudo/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1.4.3 Mais logs no cadastro
// 1.4.2 Mostra melhor formatado a mensagem de usuário já existente no cadastro
// 1.3.8 Correção da crítica da placa
// 1.3.7 Correção do cadastro
// 1.3.6 Log na conferência do convite
// 1.3.5 Log para o servidor ao logar e ao cadastrar
// 1.3.4 Confirmação de código na entrega
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
  final FocusNode _focusUsuario = FocusNode();
  final FocusNode _focusNome = FocusNode();
  final FocusNode _focusEmail = FocusNode();
  final FocusNode _focusSenha = FocusNode();
  final FocusNode _focusTelefone = FocusNode();
  final FocusNode _focusPlaca = FocusNode();
  final FocusNode _focusPix = FocusNode();
  final FocusNode _focusCnh = FocusNode();
  final FocusNode _focusDistancia = FocusNode();

  bool _cadastrando = false;

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

    // --------------------------------------
    // 🔥 1) Loga entrada na tela + versão do app
    // --------------------------------------
    _logEntrouNaTelaCadastro();

    // --------------------------------------
    // 🔥 2) Captura global de erros
    // --------------------------------------
    FlutterError.onError = (FlutterErrorDetails details) {
      API.logApp("Cadastro", "FlutterError", {
        "error": details.exception.toString(),
        "stack": details.stack.toString(),
        "versaoApp": AppConfig.versaoApp,
        "versaoAppInt": AppConfig.versaoAppInt,
      });
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      API.logApp("Cadastro", "PlatformError", {
        "error": error.toString(),
        "stack": stack.toString(),
        "versaoApp": AppConfig.versaoApp,
        "versaoAppInt": AppConfig.versaoAppInt,
      });
      return true;
    };

    // --------------------------------------
    // 🔥 3) Configurações internas
    // --------------------------------------
    _distanciaMaximaController.text = '30';
    _aplicarPrefill();
    _carregarFallbackDosPrefs();

    // --------------------------------------
    // 🔥 4) Logs ao perder o foco
    // --------------------------------------
    _focusUsuario
        .addListener(() => _logSaidaCampo("usuario", _usuarioController.text));
    _focusNome.addListener(() => _logSaidaCampo("nome", _nameController.text));
    _focusEmail
        .addListener(() => _logSaidaCampo("email", _emailController.text));
    _focusSenha
        .addListener(() => _logSaidaCampo("senha", _passwordController.text));
    _focusTelefone
        .addListener(() => _logSaidaCampo("telefone", _phoneController.text));
    _focusPlaca
        .addListener(() => _logSaidaCampo("placa", _placaController.text));
    _focusPix.addListener(() => _logSaidaCampo("pix", _pix.text));
    _focusCnh.addListener(() => _logSaidaCampo("cnh", _cnhController.text));
    _focusDistancia.addListener(() =>
        _logSaidaCampo("distanciaMaxima", _distanciaMaximaController.text));
  }

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
    _focusUsuario.dispose();
    _focusNome.dispose();
    _focusEmail.dispose();
    _focusSenha.dispose();
    _focusTelefone.dispose();
    _focusPlaca.dispose();
    _focusPix.dispose();
    _focusCnh.dispose();
    _focusDistancia.dispose();
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
              focusNode: _focusUsuario,
              decoration: const InputDecoration(labelText: 'Usuário'),
            ),
            TextField(
              controller: _nameController,
              focusNode: _focusNome,
              decoration: const InputDecoration(labelText: 'Nome Completo'),
            ),
            TextField(
              controller: _emailController,
              focusNode: _focusEmail,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              focusNode: _focusSenha,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            TextField(
              controller: _phoneController,
              focusNode: _focusTelefone,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _cnhController,
              focusNode: _focusCnh,
              decoration: const InputDecoration(labelText: 'CNH'),
            ),
            TextField(
              controller: _placaController,
              focusNode: _focusPlaca,
              decoration: const InputDecoration(labelText: 'Placa'),
            ),
            TextField(
              controller: _pix,
              focusNode: _focusPix,
              decoration: const InputDecoration(labelText: 'PIX'),
            ),
            TextField(
              controller: _distanciaMaximaController,
              focusNode: _focusDistancia,
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
              onPressed: _cadastrando ? null : _enviarCadastro,
              child: _cadastrando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Cadastrar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarCadastro() async {
    await API.logApp("Cadastro", "Início do processo de cadastro");
    setState(() => _cadastrando = true);

    if (_inviteValid == -1) {
      await _verifyInvite();
    }

    if (_inviteValid != 1) {
      await _logCadastroInvalidInvite();
      _mostrarMensagemInviteInvalido();
      setState(() => _cadastrando = false);
      return;
    }

    await _logCadastroDadosColetados();
    if (!_validarNome() || !_validarEmail() || !_validarSenha()) return;
    if (!_validarTelefone()) return;
    if (!_validarPlaca()) return;
    if (!_validarUsuario()) return;
    if (!_validarDistanciaMaxima()) return;

    try {
      await _logCadastroEnviandoDados();
      final resultado = await _realizarCadastro();

      print("=== [RegisterPage] Resultado do cadastro ===");
      print(resultado);

      // ---------------------------
      // 🔥 NOVA LÓGICA DE SUCESSO / ERRO
      // ---------------------------

      if (resultado.containsKey('Erro') && resultado['Erro'] == 0) {
        // Sucesso — salvar nos SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('idUser', resultado['id']);
        await prefs.setString('nomeUser', _nameController.text.trim());
        await prefs.setBool('isFornecedor', false); // para o motoboy

        await _logCadastroSucesso(resultado);

        _navegarParaHomePage();
        return;
      }

      // Qualquer outra coisa = falha
      await _logCadastroFalha(resultado);
      _mostrarMensagemCadastroFalhou(resultado);
      setState(() => _cadastrando = false);
    } catch (e, st) {
      setState(() => _cadastrando = false);
      await _logCadastroErroInesperado(e, st);
      _mostrarMensagemErroInesperado();
    }
  }

  Future<void> _logCadastroInvalidInvite() async {
    await API.logApp("Cadastro", "Convite inválido ou ausente", {
      "invite": _inviteController.text,
      "inviteStatus": _inviteStatus,
    });
  }

  void _mostrarMensagemInviteInvalido() {
    mostrarMensagem(
      context,
      "Você precisa de um convite válido para se cadastrar.",
    );
  }

  Future<void> _logCadastroDadosColetados() async {
    await API.logApp("Cadastro", "Dados capturados para envio", {
      "nome": _nameController.text.trim(),
      "usuario": _usuarioController.text.trim(),
      "email": _emailController.text.trim(),
      "telefone": _phoneController.text.trim(),
      "placa": _placaController.text.trim().toUpperCase(),
      "distanciaMaxima":
          int.tryParse(_distanciaMaximaController.text.trim()) ?? 30,
    });
  }

  bool _validarNome() {
    if (!validarNome(_nameController.text.trim())) {
      setState(() => _cadastrando = false);
      _logCadastroErroNomeInvalido();
      _mostrarMensagemNomeInvalido();
      return false;
    }
    return true;
  }

  Future<void> _logCadastroErroNomeInvalido() async {
    await API.logApp("Cadastro", "Erro: nome inválido");
  }

  void _mostrarMensagemNomeInvalido() {
    mostrarMensagem(context, 'Por favor, insira o nome completo.');
  }

  bool _validarEmail() {
    if (!validarEmail(_emailController.text.trim())) {
      setState(() => _cadastrando = false);
      _logCadastroErroEmailInvalido();
      _mostrarMensagemEmailInvalido();
      return false;
    }
    return true;
  }

  Future<void> _logCadastroErroEmailInvalido() async {
    await API.logApp("Cadastro", "Erro: email inválido",
        {"email": _emailController.text.trim()});
  }

  void _mostrarMensagemEmailInvalido() {
    mostrarMensagem(context, 'Por favor, insira um email válido.');
  }

  bool _validarSenha() {
    if (!validarSenha(_passwordController.text)) {
      setState(() => _cadastrando = false);
      _logCadastroErroSenhaInvalida();
      _mostrarMensagemSenhaInvalida();
      return false;
    }
    return true;
  }

  Future<void> _logCadastroErroSenhaInvalida() async {
    await API.logApp("Cadastro", "Erro: senha inválida");
  }

  void _mostrarMensagemSenhaInvalida() {
    mostrarMensagem(context,
        'A senha não pode ser vazia e deve ter no mínimo 6 caracteres.');
  }

  bool _validarPlaca() {
    final placaInput = _placaController.text.trim();
    if (placaInput.isEmpty) {
      return true;
    }
    if (!validarPlaca(placaInput)) {
      setState(() => _cadastrando = false);
      _logCadastroErroPlacaInvalida(placaInput);
      _mostrarMensagemPlacaInvalida();
      return false;
    }
    return true;
  }

  Future<void> _logCadastroErroPlacaInvalida(String placa) async {
    await API.logApp("Cadastro", "Erro: placa inválida", {"placa": placa});
  }

  void _mostrarMensagemPlacaInvalida() {
    mostrarMensagem(context, 'Por favor, insira uma placa válida.');
  }

  bool _validarUsuario() {
    if (_usuarioController.text.trim().isEmpty) {
      setState(() => _cadastrando = false);
      _logCadastroErroUsuarioEmBranco();
      _mostrarMensagemUsuarioEmBranco();
      return false;
    }
    return true;
  }

  Future<void> _logCadastroErroUsuarioEmBranco() async {
    await API.logApp("Cadastro", "Erro: usuário em branco");
  }

  void _mostrarMensagemUsuarioEmBranco() {
    mostrarMensagem(context, 'Por favor, insira o nome de usuário.');
  }

  bool _validarDistanciaMaxima() {
    final distanciaMaxStr = _distanciaMaximaController.text.trim();
    final distanciaMaxima = int.tryParse(distanciaMaxStr) ?? 30;
    if (distanciaMaxima < 1 || distanciaMaxima > 30) {
      setState(() => _cadastrando = false);
      _logCadastroErroDistanciaForaDoLimite(distanciaMaxima);
      _mostrarMensagemDistanciaForaDoLimite();
      return false;
    }
    return true;
  }

  Future<void> _logCadastroErroDistanciaForaDoLimite(int valor) async {
    await API.logApp("Cadastro", "Erro: distância fora do limite", {
      "valor": valor,
    });
  }

  void _mostrarMensagemDistanciaForaDoLimite() {
    mostrarMensagem(context, 'Digite uma distância máxima entre 1 e 30 km.');
  }

  Future<Map<String, dynamic>> _realizarCadastro() async {
    return await API.registerUser(
      _nameController.text.trim(),
      _usuarioController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _phoneController.text.trim(),
      _cnhController.text.trim(),
      _placaController.text.trim().toUpperCase(),
      _pix.text.trim(),
      0,
      int.tryParse(_distanciaMaximaController.text.trim()) ?? 30,
    );
  }

  Future<void> _logCadastroEnviandoDados() async {
    await API.logApp("Cadastro", "Enviando dados para API /cadboy");
  }

  Future<void> _logCadastroSucesso(Map<String, dynamic> resultado) async {
    await API.logApp("Cadastro", "Cadastro bem-sucedido", resultado);
  }

  void _navegarParaHomePage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  Future<void> _logCadastroFalha(Map<String, dynamic> resultado) async {
    await API.logApp("Cadastro", "Falha no cadastro", resultado);
  }

  void _mostrarMensagemCadastroFalhou(Map<String, dynamic> resultado) {
    String msg = "";

    if (resultado.containsKey('DescErro') && resultado['DescErro'] != null) {
      msg = resultado['DescErro'];
    } else if (resultado.containsKey('message') &&
        resultado['message'] != null) {
      msg = resultado['message'];
    } else {
      msg = "Não foi possível concluir o cadastro.";
    }

    print("[ERRO_EXIBIDO] $msg");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _logCadastroErroInesperado(Object e, StackTrace st) async {
    await API.logApp("Cadastro", "Erro inesperado", {
      "erro": e.toString(),
      "stack": st.toString(),
    });
  }

  void _mostrarMensagemErroInesperado() {
    mostrarMensagem(context, "Erro inesperado durante o cadastro.");
  }

  //       mostrarMensagem(context, 'Cadastro bem-sucedido');
  //       Navigator.of(context).pushReplacement(
  //         MaterialPageRoute(builder: (context) => const HomePage()),
  //       );
  //     } else {
  //       await API.logApp("Cadastro", "Falha no cadastro", resultado);
  //       mostrarMensagem(
  //         context,
  //         resultado['message'],
  //         details: resultado['details'],
  //       );
  //     }
  //   } catch (e, st) {
  //     setState(() => _cadastrando = false);
  //     await API.logApp("Cadastro", "Erro inesperado", {
  //       "erro": e.toString(),
  //       "stack": st.toString(),
  //     });
  //     mostrarMensagem(context, "Erro inesperado durante o cadastro.");
  //   }
  // }

  bool validarPlaca(String input) {
    final placa = input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (placa.length != 7) return false;
    final regex = RegExp(r'^[A-Z]{3}[0-9][0-9A-Z][0-9]{2}$');
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

  void mostrarMensagem(BuildContext context, String mensagem,
      {String? details}) {
    String detalheFormatado = "";

    if (details != null) {
      try {
        // Tenta decodificar o JSON interno
        final decoded = json.decode(details);

        // Se tiver o padrão do servidor (Erro e DescErro)
        if (decoded is Map && decoded.containsKey('DescErro')) {
          detalheFormatado = decoded['DescErro'];
        } else {
          // Caso seja outro formato, exibe indentado
          detalheFormatado =
              const JsonEncoder.withIndent('  ').convert(decoded);
        }
      } catch (e) {
        // Se falhar a decodificação, mostra o texto original
        detalheFormatado = details;
      }
    }

    if (details == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagem)));
      return;
    }

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
            if (detalheFormatado.isNotEmpty) ...[
              const Text('Detalhes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              SelectableText(detalheFormatado),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: detalheFormatado));
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

  bool _validarTelefone() {
    final telefone = _phoneController.text.trim();

    if (telefone.isEmpty) {
      setState(() => _cadastrando = false);
      mostrarMensagem(context, 'Por favor, insira um número de telefone.');
      return false;
    }
    return true;
  }

  Future<void> _logSaidaCampo(String campo, String valor) async {
    if (mounted && !_cadastrando) {
      if (!_getFocusOf(campo).hasFocus) {
        await API.logApp(
            "Cadastro", "Campo alterado", {"campo": campo, "valor": valor});
        print("[LOG_CAMPO] $campo => $valor");
      }
    }
  }

  FocusNode _getFocusOf(String campo) {
    switch (campo) {
      case "usuario":
        return _focusUsuario;
      case "nome":
        return _focusNome;
      case "email":
        return _focusEmail;
      case "senha":
        return _focusSenha;
      case "telefone":
        return _focusTelefone;
      case "placa":
        return _focusPlaca;
      case "pix":
        return _focusPix;
      case "cnh":
        return _focusCnh;
      case "distanciaMaxima":
        return _focusDistancia;
      default:
        return FocusNode();
    }
  }

  Future<void> _logEntrouNaTelaCadastro() async {
    await API.logApp("Cadastro", "Entrou na tela de cadastro", {
      "versaoApp": AppConfig.versaoApp,
      "versaoAppInt": AppConfig.versaoAppInt,
    });
  }
}
