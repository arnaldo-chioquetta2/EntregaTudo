import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

typedef GenerateInviteCode = Future<Map<String, dynamic>> Function();
typedef CheckInviteAvailability = Future<Map<String, dynamic>> Function(
    String code, int userId);
typedef SaveInviteCode = Future<Map<String, dynamic>> Function(
    String code, int userId);
typedef CanLaunchInvite = Future<bool> Function(Uri uri);
typedef LaunchInvite = Future<bool> Function(Uri uri);

class CaptadorPanelPage extends StatefulWidget {
  const CaptadorPanelPage({
    super.key,
    this.generateInviteCode,
    this.checkInviteAvailability,
    this.saveInviteCode,
    this.canLaunchInvite,
    this.launchInvite,
    this.preferencesProvider,
  });

  final GenerateInviteCode? generateInviteCode;
  final CheckInviteAvailability? checkInviteAvailability;
  final SaveInviteCode? saveInviteCode;
  final CanLaunchInvite? canLaunchInvite;
  final LaunchInvite? launchInvite;
  final Future<SharedPreferences> Function()? preferencesProvider;

  @override
  State<CaptadorPanelPage> createState() => _CaptadorPanelPageState();
}

class _CaptadorPanelPageState extends State<CaptadorPanelPage> {
  final TextEditingController _inviteController = TextEditingController();
  String? _statusMessage;
  bool _isLoading = false;
  int? _userId;

  Future<SharedPreferences> get _preferences =>
      (widget.preferencesProvider ?? SharedPreferences.getInstance)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _carregarCodigoInicial());
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Gerando código...';
    });
    try {
      final result =
          await (widget.generateInviteCode ?? API.generateInviteCode)();
      final code = (result['code'] ?? 'ERRO').toString();
      if (!mounted) return;
      setState(() => _statusMessage = 'Código gerado com sucesso.');
      _inviteController.text = code;
    } catch (_) {
      if (mounted) setState(() => _statusMessage = 'Erro ao gerar código.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAvailability() async {
    if (_isLoading) return;
    final code = _inviteController.text.trim();
    if (code.isEmpty || _userId == null) {
      setState(() =>
          _statusMessage = 'Informe um código e verifique se está disponível.');
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Verificando disponibilidade...';
    });
    try {
      final result = await (widget.checkInviteAvailability ??
          API.checkInviteAvailability)(code, _userId!);
      final available = result['available'] == true;
      if (mounted) {
        setState(() => _statusMessage = available
            ? 'Código disponível para uso!'
            : 'Código já está em uso.');
      }
    } catch (_) {
      if (mounted) setState(() => _statusMessage = 'Erro ao verificar código.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCode() async {
    if (_isLoading) return;
    final code = _inviteController.text.trim();
    if (code.isEmpty || _userId == null) {
      setState(() => _statusMessage = 'Preencha um código antes de salvar.');
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Salvando código...';
    });
    try {
      final result =
          await (widget.saveInviteCode ?? API.setInvite)(code, _userId!);
      final success = result['success'] == true;
      if (mounted) {
        setState(() => _statusMessage = success
            ? 'Código salvo com sucesso!'
            : (result['message'] ?? 'Erro ao salvar código.').toString());
      }
      if (success) {
        final prefs = await _preferences;
        await prefs.setString('inviteCode', code);
      }
    } catch (_) {
      if (mounted) setState(() => _statusMessage = 'Erro ao salvar código.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarCodigoInicial() async {
    final prefs = await _preferences;
    _userId = prefs.getInt('idUser');
    final backendInvite = prefs.getString('convite');
    final localCode = prefs.getString('inviteCode');
    final userName = prefs.getString('nomeUser');
    var code = '';
    if (backendInvite != null && backendInvite.trim().isNotEmpty) {
      code = backendInvite.trim().toUpperCase();
    } else if (localCode != null && localCode.trim().isNotEmpty) {
      code = localCode.trim().toUpperCase();
    } else if (userName != null && userName.trim().isNotEmpty) {
      code = _gerarCodigoDeNome(userName);
    }
    if (!mounted) return;
    setState(() => _inviteController.text = code);
  }

  String _gerarCodigoDeNome(String nome) {
    final clean = nome.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    return clean.length >= 8 ? clean.substring(0, 8) : clean.padRight(8, 'X');
  }

  Future<void> _enviarConviteWhatsApp() async {
    if (_isLoading) return;
    final prefs = await _preferences;
    final userName = prefs.getString('nomeUser') ?? 'Um amigo';
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      setState(() => _statusMessage =
          'Gere ou salve um código antes de enviar o convite.');
      return;
    }
    final inviteUri = Uri.https('teletudo.com', '/convite', {'id': code});
    final message = Uri.encodeComponent(
        '$userName está lhe convidando para o TeleTudo, onde todos ganham!\n$inviteUri');
    final whatsappUrl = Uri.parse('https://wa.me/?text=$message');
    try {
      final canLaunch =
          await (widget.canLaunchInvite ?? canLaunchUrl)(whatsappUrl);
      if (canLaunch) {
        final launched = await (widget.launchInvite ??
                (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(
            whatsappUrl);
        if (launched) return;
      }
    } catch (_) {}
    if (mounted)
      setState(() => _statusMessage = 'Não foi possível abrir o WhatsApp.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasCode = _inviteController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Captador')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.group_add_outlined,
                      color: colors.primary, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Código de convite',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                            'Gere ou use um código para compartilhar um convite.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasCode ? 'Seu código' : 'Nenhum código disponível',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Código do convite',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _generateCode,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Gerar código'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _checkAvailability,
                          icon: const Icon(Icons.search),
                          label: const Text('Verificar disponibilidade'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saveCode,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Salvar código'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _enviarConviteWhatsApp,
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Compartilhar via WhatsApp'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: colors.primary),
                title: Text(_statusMessage!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
