import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// 1.4.6 CorreÃ§Ã£o do convite que estava aparecendo um errado no painel do captador

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
      print(
          '[CAPTADOR] PostFrameCallback â†’ chamando _carregarCodigoInicial');
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
      _statusMessage = "Gerando cÃ³digo...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.generateInviteCode();
      final code = result['code'] ?? 'ERRO';
      _inviteController.text = code;

      setState(() {
        _statusMessage = "CÃ³digo gerado com sucesso: $code";
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao gerar cÃ³digo.";
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
        _statusMessage =
            "Informe um cÃ³digo e verifique se estÃ¡ disponÃ­vel.";
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
            ? "CÃ³digo disponÃ­vel para uso!"
            : "CÃ³digo jÃ¡ estÃ¡ em uso.";
        _statusColor = available ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao verificar cÃ³digo.";
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
        _statusMessage = "Preencha um cÃ³digo antes de salvar.";
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Salvando cÃ³digo...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.setInvite(code, _userId!);
      final success = result['success'] == true;

      setState(() {
        _statusMessage = success
            ? "CÃ³digo salvo com sucesso!"
            : result['message'] ?? "Erro ao salvar cÃ³digo.";
        _statusColor = success ? Colors.green : Colors.red;
      });

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('inviteCode', code);
        print('[CAPTADOR] inviteCode_persistido=true');
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao salvar cÃ³digo.";
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
    print('[CAPTADOR] prefs_carregadas=true');

    // ðŸ”¹ 1) Convite vindo do backend (login)
    final backendConvite = prefs.getString('convite');
    print(
        '[CAPTADOR] convite_backend_presente=${backendConvite != null && backendConvite.trim().isNotEmpty}');

    // ðŸ”¹ 2) CÃ³digo salvo manualmente no painel
    final localCode = prefs.getString('inviteCode');
    print(
        '[CAPTADOR] convite_local_presente=${localCode != null && localCode.trim().isNotEmpty}');

    String codigoFinal = '';

    if (backendConvite != null && backendConvite.trim().isNotEmpty) {
      // ðŸ‘‰ PRIORIDADE MÃXIMA
      codigoFinal = backendConvite.trim().toUpperCase();
      print('[CAPTADOR] origem_convite=backend');
    } else if (localCode != null && localCode.trim().isNotEmpty) {
      codigoFinal = localCode.trim().toUpperCase();
      print(
          '[CAPTADOR] convite_local_presente=${localCode != null && localCode.trim().isNotEmpty}');
    } else if (nomeUsuario != null && nomeUsuario.trim().isNotEmpty) {
      codigoFinal = _gerarCodigoDeNome(nomeUsuario);
      print('[CAPTADOR] origem_convite=gerado');
    } else {
      print('[CAPTADOR] Nenhum dado disponÃ­vel para gerar cÃ³digo.');
      codigoFinal = '';
    }

    if (!mounted) {
      print('[CAPTADOR] Widget desmontado, abortando atualizaÃ§Ã£o.');
      return;
    }

    setState(() {
      _inviteController.text = codigoFinal;
    });
    print('[CAPTADOR] campo_atualizado=true');
  }

  String _gerarCodigoDeNome(String nome) {
    final limpo = nome.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final gerado =
        limpo.length >= 8 ? limpo.substring(0, 8) : limpo.padRight(8, 'X');
    print('[CAPTADOR] codigo_gerado=true');
    return gerado;
  }

  Future<void> _enviarConviteWhatsApp() async {
    debugPrint('[ConviteWhatsApp] acionado');
    debugPrint('[ConviteWhatsApp] tipo_perfil=entregador');
    final prefs = await SharedPreferences.getInstance();
    final nomeUsuario = prefs.getString('nomeUser') ?? 'Um amigo';
    final codigoConvite = _inviteController.text.trim();

    if (codigoConvite.isEmpty) {
      setState(() {
        _statusMessage =
            "Gere ou salve um c\u00f3digo antes de enviar o convite.";
        _statusColor = Colors.red;
      });
      return;
    }

    final conviteUri = Uri.https('teletudo.com', '/convite', {
      'id': codigoConvite,
    });
    final mensagem = Uri.encodeComponent(
      "$nomeUsuario est\u00e1 lhe convidando para o TeleTudo, onde todos ganham!\n"
      "$conviteUri",
    );

    final whatsappUrl = Uri.parse("https://wa.me/?text=$mensagem");
    final maskedCode = codigoConvite.length > 3
        ? '${codigoConvite.substring(0, 3)}...'
        : '***';
    debugPrint(
      '[ConviteWhatsApp] url_destino=https://teletudo.com/convite?id=$maskedCode',
    );
    debugPrint('[ConviteWhatsApp] launch_iniciado');

    try {
      final canLaunch = await canLaunchUrl(whatsappUrl);
      if (canLaunch) {
        final launched = await launchUrl(
          whatsappUrl,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('[ConviteWhatsApp] launch_resultado=$launched');
        if (launched) return;
      } else {
        debugPrint('[ConviteWhatsApp] launch_resultado=false');
      }
    } catch (e) {
      debugPrint('[ConviteWhatsApp] excecao=${e.runtimeType}');
    }

    setState(() {
      _statusMessage = "N\u00e3o foi poss\u00edvel abrir o WhatsApp.";
      _statusColor = Colors.red;
    });
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
              "Gerar ou configurar cÃ³digo de convite",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _inviteController,
              decoration: const InputDecoration(
                labelText: "CÃ³digo do convite (8 letras maiÃºsculas)",
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
                    label: const Text("Gerar cÃ³digo aleatÃ³rio"),
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
                    label: const Text("Salvar cÃ³digo"),
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
