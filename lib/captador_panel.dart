import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// 1.4.6 Correção do convite que estava aparecendo um errado no painel do captador

class CaptadorPanelPage extends StatefulWidget {
  const CaptadorPanelPage({super.key});

  @override
  State<CaptadorPanelPage> createState() => _CaptadorPanelPageState();
}

class _CaptadorPanelPageState extends State<CaptadorPanelPage> {
  final TextEditingController _inviteController = TextEditingController();
  String? _statusMessage;
  Color _statusColor = Colors.black;
  bool _isLoading = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    print('[CAPTADOR] initState chamado');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[CAPTADOR] PostFrameCallback → chamando _carregarCodigoInicial');
      _carregarCodigoInicial();
    });
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Gerando código...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.generateInviteCode();
      final code = result['code'] ?? 'ERRO';
      _inviteController.text = code;

      setState(() {
        _statusMessage = "Código gerado com sucesso: $code";
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao gerar código.";
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAvailability() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty || _userId == null) {
      setState(() {
        _statusMessage = "Informe um código e verifique se está disponível.";
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Verificando disponibilidade...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.checkInviteAvailability(code, _userId!);
      final available = result['available'] == true;

      setState(() {
        _statusMessage = available
            ? "Código disponível para uso!"
            : "Código já está em uso.";
        _statusColor = available ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao verificar código.";
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCode() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty || _userId == null) {
      setState(() {
        _statusMessage = "Preencha um código antes de salvar.";
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Salvando código...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.setInvite(code, _userId!);
      final success = result['success'] == true;

      setState(() {
        _statusMessage = success
            ? "Código salvo com sucesso!"
            : result['message'] ?? "Erro ao salvar código.";
        _statusColor = success ? Colors.green : Colors.red;
      });

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('inviteCode', code);
        print('[CAPTADOR] inviteCode persistido nas prefs="$code"');
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao salvar código.";
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarCodigoInicial() async {
    print('[CAPTADOR] Iniciando _carregarCodigoInicial()');

    final prefs = await SharedPreferences.getInstance();

    _userId = prefs.getInt('idUser');
    final nomeUsuario = prefs.getString('nomeUser');

    print('[CAPTADOR] prefs: idUser=$_userId, nomeUser="$nomeUsuario"');

    // 🔹 1) Convite vindo do backend (login)
    final backendConvite = prefs.getString('convite');
    print('[CAPTADOR] Convite do backend (prefs.convite): "$backendConvite"');

    // 🔹 2) Código salvo manualmente no painel
    final localCode = prefs.getString('inviteCode');
    print('[CAPTADOR] Código salvo localmente (prefs.inviteCode): "$localCode"');

    String codigoFinal = '';

    if (backendConvite != null && backendConvite.trim().isNotEmpty) {
      // 👉 PRIORIDADE MÁXIMA
      codigoFinal = backendConvite.trim().toUpperCase();
      print('[CAPTADOR] Usando convite do backend: $codigoFinal');
    } else if (localCode != null && localCode.trim().isNotEmpty) {
      codigoFinal = localCode.trim().toUpperCase();
      print('[CAPTADOR] Usando código salvo localmente: $codigoFinal');
    } else if (nomeUsuario != null && nomeUsuario.trim().isNotEmpty) {
      codigoFinal = _gerarCodigoDeNome(nomeUsuario);
      print('[CAPTADOR] Gerado a partir do nome: $codigoFinal');
    } else {
      print('[CAPTADOR] Nenhum dado disponível para gerar código.');
      codigoFinal = '';
    }

    if (!mounted) {
      print('[CAPTADOR] Widget desmontado, abortando atualização.');
      return;
    }

    setState(() {
      _inviteController.text = codigoFinal;
    });

    print('[CAPTADOR] Campo atualizado: "${_inviteController.text}"');
  }

  String _gerarCodigoDeNome(String nome) {
    final limpo = nome.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final gerado =
        limpo.length >= 8 ? limpo.substring(0, 8) : limpo.padRight(8, 'X');
    print('[CAPTADOR] _gerarCodigoDeNome("$nome") => "$gerado"');
    return gerado;
  }

  Future<void> _enviarConviteWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    final nomeUsuario = prefs.getString('nomeUser') ?? 'Um amigo';
    final codigoConvite = _inviteController.text.trim();

    if (codigoConvite.isEmpty) {
      setState(() {
        _statusMessage = "Gere ou salve um código antes de enviar o convite.";
        _statusColor = Colors.red;
      });
      return;
    }

    final mensagem = Uri.encodeComponent(
      "$nomeUsuario está lhe convidando para o TeleTudo, onde todos ganham!\n"
      "https://teletudo.com/convite?id=$codigoConvite",
    );

    final whatsappUrl = Uri.parse("https://wa.me/?text=$mensagem");
    print('[CAPTADOR] Enviando convite via WhatsApp: $whatsappUrl');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      setState(() {
        _statusMessage = "Não foi possível abrir o WhatsApp.";
        _statusColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Captador'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Gerar ou configurar código de convite",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _inviteController,
              decoration: const InputDecoration(
                labelText: "Código do convite (8 letras maiúsculas)",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _generateCode,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Gerar código aleatório"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _checkAvailability,
                    icon: const Icon(Icons.search),
                    label: const Text("Verificar disponibilidade"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _saveCode,
                    icon: const Icon(Icons.save),
                    label: const Text("Salvar código"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _enviarConviteWhatsApp,
                    icon: const FaIcon(FontAwesomeIcons.whatsapp),
                    label: const Text("Enviar convite via WhatsApp"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
