import 'dart:io';
import 'dart:async';
import 'settingsPage.dart';
import 'package:intl/intl.dart';
import 'models/entrega_ativa.dart';
import 'package:entregatudo/api.dart';
import 'package:entregatudo/app_update_info.dart';
import 'package:entregatudo/app_update_service.dart';
import 'package:entregatudo/constants.dart';
import 'services/entrega_service.dart';
import 'package:flutter/material.dart';
import 'features/location_service.dart';
import 'features/home_operational_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:entregatudo/utils/sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entregatudo/utils/online_status_service.dart';
import 'fornecedor_entregadores_preferences_page.dart';

// 1.4.8 Ajustes nas Apis
// 1.4.7 Fornecedor por horÃƒÂ¡rios
// 1.4.4 MotoBoy e Fornecedor ao mesmo tempo
// 1.4.3 Modo offline para MotoBoy e Fornecedor
// 1.4.0 CorreÃƒÂ§ÃƒÂ£o estavam sendo mostradas vendas falsas
// 1.3.9 Fornecedor recebe aviso pelo App sobre a venda
// 1.2.4 Conserto do link para as configuraÃƒÂ§ÃƒÂµes

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.operationalController});

  final HomeOperationalController? operationalController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color corOnline = Color(0xFFF57C00); // Laranja
  static const Color corOffline = Color(0xFF2E7D32); // Verde

  late final HomeOperationalController _operationalController =
      widget.operationalController ?? HomeOperationalController();

  LocationService get _locationService => _operationalController.locationService;
  Map<String, dynamic>? deliveryData;
  String? statusMessage;
  bool hasPickedUp = false;
  bool deliveryCompleted = false;
  bool hasAcceptedDelivery = false;
  String saldo = 'R\$ 0,00';
  double saldoNum = 0.0;

  int lojasNoRaio = 0;
  bool isSaldoAtualizado = false;
  bool isCheckingLogin = false;
  String _ts() => DateTime.now().toIso8601String();
  File? _logFile;
  bool _dialogAberto = false;
  int? userId;
  int? idLoja;
  bool isMotoboy = false;
  bool isFornecedor = false;
  bool get isMotoBoyOnline => _operationalController.motoboyOnline;
  set isMotoBoyOnline(bool value) =>
      _operationalController.setMotoboyOnline(value);
  bool get _motoboyTrackingActive =>
      _operationalController.motoboyTrackingActive;
  set _motoboyTrackingActive(bool value) =>
      _operationalController.motoboyTrackingActive = value;
  bool get isFornecedorOnline => _operationalController.fornecedorOnline;
  set isFornecedorOnline(bool value) =>
      _operationalController.setFornecedorOnline(value);
  int _quantidadeFavoritosRecebidos = 0;
  String? _nomeEmpresaFavorita;
  bool get hbPausadoPorEntrega =>
      _operationalController.heartbeatPausedByDelivery;
  set hbPausadoPorEntrega(bool value) =>
      _operationalController.heartbeatPausedByDelivery = value;
  bool get hbPausadoPorVenda =>
      _operationalController.heartbeatPausedBySale;
  set hbPausadoPorVenda(bool value) =>
      _operationalController.heartbeatPausedBySale = value;
  bool get proximoEhFornecedor =>
      _operationalController.nextHeartbeatIsFornecedor;
  set proximoEhFornecedor(bool value) =>
      _operationalController.nextHeartbeatIsFornecedor = value;
  final TextEditingController _codigoClienteController =
      TextEditingController();
  String? erroCodigoCliente;
  bool enviandoCodigoCliente = false;
  double? valorEntregaAtual;
  AppUpdateInfo? _appUpdateInfo;

  EntregaAtiva? get entregaAtiva => _operationalController.entregaAtiva;
  set entregaAtiva(EntregaAtiva? value) => _operationalController.entregaAtiva = value;

  Map<String, dynamic>? get deliveryDataMotoboy => _operationalController.deliveryDataMotoboy;
  set deliveryDataMotoboy(Map<String, dynamic>? value) =>
      _operationalController.deliveryDataMotoboy = value;
  Map<String, dynamic>? get deliveryDataFornecedor =>
      _operationalController.deliveryDataFornecedor;
  set deliveryDataFornecedor(Map<String, dynamic>? value) =>
      _operationalController.deliveryDataFornecedor = value;

  Future<void> _toggleMotoBoyOnline() async {
    await _setMotoboyOnline(!isMotoBoyOnline);
  }

  Future<void> _setMotoboyOnline(bool online) async {
    if (!isMotoboy) return;
    try {
      if (online) {
        await _locationService.requestPermissions();
        _motoboyTrackingActive = true;
        _locationService.startTracking((position) async {
          if (!isMotoBoyOnline || !_motoboyTrackingActive) return;
          final prefs = await SharedPreferences.getInstance();
          await _processaMotoboy(prefs, position.latitude, position.longitude);
        });
        await OnlineStatusService.setMotoStatus(true);
      } else {
        _motoboyTrackingActive = false;
        _locationService.stopTracking();
        await OnlineStatusService.setMotoStatus(false);
        if (userId != null) await API.motoOff(userId!);
      }
      if (!mounted) return;
      setState(() => isMotoBoyOnline = online);
      if (online) agendarProximoHeartbeat();
    } catch (e) {
      _motoboyTrackingActive = false;
      _locationService.stopTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Nao foi possivel alterar a disponibilidade: $e')),
        );
      }
    }
  }

  void _toggleFornecedorOnline() {
    setState(() => isFornecedorOnline = !isFornecedorOnline);
  }

  Future<void> _initLogFile() async {
    if (kIsWeb) {
      print('[LOG ${_ts()}] (Web) Logs apenas no console.');
      return;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/entregatudo_logs.txt');
      if (!(await _logFile!.exists())) {
        await _logFile!.create(recursive: true);
      }
      print('[LOG ${_ts()}] Arquivo de log inicializado em: ${_logFile!.path}');
    } catch (e) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
    }
  }

  Future<void> _log(String msg) async {
    final line = '[HomePage ${_ts()}] $msg';
    print(line);

    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString('$line\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
    }
  }

  late Future<void> _initFuture;

  int intervalo = kIsWeb ? 5 : 1;

  @override
  void initState() {
    super.initState();
    _initLogFile();

    // Ã°Å¸â€Â¥ Carrega estados de online/offline
    _carregarOnlineStatus();

    // Ã°Å¸â€Â¥ Continua fluxo normal
    _initFuture = _verificarLoginOuCadastro();
    _verificarAtualizacaoApp();
  }

  Future<void> _verificarAtualizacaoApp() async {
    debugPrint('[HomePage][AppUpdate] verificacao_solicitada');
    final resultado = await AppUpdateService.checkForUpdate();
    if (!mounted) {
      debugPrint('[HomePage][AppUpdate] tela_descartada_antes_do_resultado');
      return;
    }
    setState(() => _appUpdateInfo = resultado);
    debugPrint('[HomePage][AppUpdate] consulta_concluida');
    debugPrint('[HomePage][AppUpdate] status=' + resultado.status.name);
    debugPrint('[HomePage][AppUpdate] current_version=' +
        (resultado.currentVersion ?? '(indisponivel)'));
    debugPrint('[HomePage][AppUpdate] latest_version=' +
        (resultado.latestVersion ?? '(indisponivel)'));
    debugPrint('[HomePage][AppUpdate] update_available=' +
        (resultado.status == AppUpdateStatus.updateAvailable).toString());
    debugPrint('[HomePage][AppUpdate] estado_atualizado');
  }

  Future<void> _abrirDownloadAtualizacao() async {
    final info = _appUpdateInfo;
    if (info == null) return;
    debugPrint('[HomePage][AppUpdate] download_acionado');
    final opened = await AppUpdateService.openDownload(info);
    debugPrint('[HomePage][AppUpdate] download_aberto=' + opened.toString());
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'NÃ£o foi possÃ­vel abrir o download da atualizaÃ§Ã£o.')),
    );
  }

  Future<void> _verificarLoginOuCadastro() async {
    if (isCheckingLogin) {
      _log(
          'Ignorado: verificaÃƒÂ§ÃƒÂ£o jÃƒÂ¡ em andamento.');
      return;
    }
    isCheckingLogin = true;
    _log(
        "Iniciando verificaÃƒÂ§ÃƒÂ£o de login ou cadastro");

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('idUser');

      // ============================================================
      // PERFIS Ã¢â‚¬â€œ O usuÃƒÂ¡rio pode ser SOMENTE motoboy OU fornecedor
      // ============================================================
      isFornecedor = prefs.getBool('isFornecedor') ?? false;
      isMotoboy = prefs.getBool('isMotoboy') ?? false;

      _log(
          "Perfis carregados Ã¢â€ â€™ Motoboy=$isMotoboy | Fornecedor=$isFornecedor");

      // ============================================================
      // VERIFICA LOGIN
      // ============================================================
      if (userId == null || userId == 0) {
        _log("UsuÃ¡rio nÃ£o logado. Indo para tela de registro.");
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/register');
        return;
      }

      // ============================================================
      // CARREGAR ID DA LOJA (apenas fornecedor)
      // ============================================================
      if (isFornecedor) {
        idLoja = prefs.getInt('idLoja');
        _log("idLoja carregado = $idLoja");
      }

      if (isMotoboy) {
        await _carregarFavoritosRecebidos();
      } else {
        print(
            '[PerfilEntregador] carregamento_ignorado motivo=usuario_nao_motoboy');
      }

      // ============================================================
      // CARREGAR ESTADO ONLINE/OFFLINE
      // ============================================================
      final persistedMotoOnline = await OnlineStatusService.getMotoStatus();
      isMotoBoyOnline = false;
      _log(
          "Status online persistido=$persistedMotoOnline; aguardando confirmacao explicita");
      isFornecedorOnline = isFornecedor
          ? await OnlineStatusService.getFornecedorStatus()
          : false;

      _log(
          "OnlineStatus Ã¢â€ â€™ MotoBoy=$isMotoBoyOnline | Fornecedor=$isFornecedorOnline");

      // ============================================================
      // PERMISSÃƒâ€¢ES DE LOCALIZAÃƒâ€¡ÃƒÆ’O
      // ============================================================
      // ============================================================
      // ATUALIZAR SALDO
      // ============================================================
      _log("Atualizando saldo...");
      await updateSaldo();

      // ============================================================
      // AGENDAR HEARTBEAT
      // ============================================================
      _log("Agendando heartbeat (intervalo=$intervalo s)...");

      // _scheduleNextHeartbeat(intervalo);
      agendarProximoHeartbeat();

      _log(
          "VerificaÃƒÂ§ÃƒÂ£o concluÃƒÂ­da com sucesso.");
    } catch (e, st) {
      _log('ERRO em _verificarLoginOuCadastro: $e\n$st');
    } finally {
      isCheckingLogin = false;
    }
  }

  @override
  void dispose() {
    if (widget.operationalController == null) {
      _operationalController.disposeSession();
    }
    _codigoClienteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EntregaTudo ${AppConfig.versaoApp}'),
        centerTitle: true,
      ),
      body: Center(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Erro: ${snapshot.error}');
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ===========================================================
                  // Ã°Å¸â€Â ENTREGA ATIVA (NOVO BLOCO 1.5.x)
                  // ===========================================================
                  if (entregaAtiva != null) buildEntregaAtivaCard(),

                  // Ã°Å¸â€â€ Oferta nova (somente se NÃƒÆ’O houver entrega ativa)
                  if (entregaAtiva == null &&
                      deliveryDataMotoboy != null &&
                      deliveryDataMotoboy!.containsKey('chamado'))
                    _buildDeliveryDetails(),

                  // ------------------------------
                  // CONFIGURAÃƒâ€¡Ãƒâ€¢ES (somente MOTOBOY)
                  // ------------------------------
                  if (isMotoboy) ...[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SettingsPage()),
                        );
                      },
                      child: const Text('ConfiguraÃ§Ãµes'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(150, 40),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ------------------------------
                  // SALDO / RESGATE / PAINEL
                  // ------------------------------
                  if (isMotoboy || isFornecedor) ...[
                    Text(
                      "Saldo $saldo",
                      style: const TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    if (_appUpdateInfo?.status ==
                            AppUpdateStatus.updateAvailable &&
                        (_appUpdateInfo?.latestVersion?.trim().isNotEmpty ??
                            false))
                      Card(
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.system_update),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Nova versÃ£o ' +
                                          _appUpdateInfo!.latestVersion! +
                                          ' disponÃ­vel',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _abrirDownloadAtualizacao,
                                  child: Text('Atualizar para ' +
                                      _appUpdateInfo!.latestVersion!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isMotoboy &&
                        _quantidadeFavoritosRecebidos == 1 &&
                        _nomeEmpresaFavorita != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_nomeEmpresaFavorita!} tem vocÃª como favorito',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isMotoboy && _quantidadeFavoritosRecebidos > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$_quantidadeFavoritosRecebidos fornecedores tÃªm vocÃª como favorito',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/captador-panel');
                      },
                      child: const Text('Painel do Captador'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(150, 40),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // =====================================================
                  // BLOCO MOTOBOY
                  // =====================================================
                  if (isMotoboy) ...[
                    Text(
                      'Lojas Abertas: $lojasNoRaio',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    if (statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          statusMessage!,
                          style: TextStyle(
                            fontSize: 18,
                            color: statusMessage!.startsWith("Voce ganhou")
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 20),

                  // ---------------------------
                  // BOTÃƒÆ’O ON/OFF MOTOBOY
                  // ---------------------------
                  if (isMotoboy) ...[
                    ElevatedButton(
                      onPressed: () async {
                        final novoStatus = !isMotoBoyOnline;
                        await _setMotoboyOnline(novoStatus);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 45),
                        backgroundColor:
                            isMotoBoyOnline ? corOnline : corOffline,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isMotoBoyOnline
                            ? "Passar para OffLine (MotoBoy)"
                            : "Passar para OnLine (MotoBoy)",
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ---------------------------
                  // BOTÃƒÆ’O ON/OFF FORNECEDOR
                  // ---------------------------
                  if (isFornecedor) ...[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const FornecedorEntregadoresPreferencesPage(),
                          ),
                        );
                      },
                      child: const Text('PreferÃªncias de entregadores'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final novoStatus = !isFornecedorOnline;
                        await OnlineStatusService.setFornecedorStatus(
                            novoStatus);

                        if (!novoStatus) {
                          await API.fornecedorOff(idLoja: idLoja);
                        }

                        setState(() => isFornecedorOnline = novoStatus);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 45),
                        backgroundColor:
                            isFornecedorOnline ? corOnline : corOffline,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isFornecedorOnline
                            ? "Passar para OffLine (Fornecedor)"
                            : "Passar para OnLine (Fornecedor)",
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    final data = deliveryDataMotoboy;

    if (data == null) return const SizedBox.shrink();

    // SeguranÃƒÂ§a total contra campos faltando
    final enderIN = data['enderIN'] ?? 'Desconhecido';
    final enderFN = data['enderFN'] ?? 'Desconhecido';

    final distRaw = data['dist'];
    final valorRaw = data['valor'];

    final double? dist = (distRaw is num)
        ? distRaw.toDouble()
        : double.tryParse(distRaw?.toString() ?? '');

    final double? valor = (valorRaw is num)
        ? valorRaw.toDouble()
        : double.tryParse(valorRaw?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalhes da Entrega:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // ------------------ LOCAL ------------------
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text('De: $enderIN'),
              subtitle: Text('Para: $enderFN'),
            ),

            // ------------------ DISTÃƒâ€šNCIA ------------------
            ListTile(
              leading: const Icon(Icons.map),
              title: Text(
                dist != null
                    ? 'DistÃ¢ncia: ${dist.toStringAsFixed(1)} km'
                    : 'DistÃ¢ncia: --',
              ),
            ),

            // ------------------ VALOR ------------------
            ListTile(
              leading: const Icon(Icons.monetization_on, color: Colors.green),
              title: Text(
                valor != null
                    ? 'Valor: R\$ ${valor.toStringAsFixed(2)}'
                    : 'Valor: --',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // ------------------ BOTÃƒâ€¢ES ------------------
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => handleDeliveryResponse(true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 40),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    'Aceitar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => handleDeliveryResponse(false),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 40),
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Recusar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleNextHeartbeat(int seconds) {
    try {
      _log(
          "Ã¢ÂÂ³ Agendando prÃƒÂ³ximo heartbeat (${seconds}s)Ã¢â‚¬Â¦ cancelando anterior=${_operationalController.heartbeatTimer != null}");

      _operationalController.cancelHeartbeatTimer();

      _operationalController.scheduleHeartbeat(Duration(seconds: seconds), () async {
        _log("Ã¢ÂÂ± Tick do heartbeat chegou");

        // ------------------------------------------------------
        // 1) SE AMBOS ESTÃƒÆ’O OFFLINE NOS BOTÃƒâ€¢ES
        // ------------------------------------------------------
        if (!isMotoBoyOnline && !isFornecedorOnline) {
          _log(
              "Ã¢Å¡Â Ã¯Â¸Â Nenhum perfil estÃƒÂ¡ online Ã¢â€ â€™ Heartbeat nÃƒÂ£o serÃƒÂ¡ enviado.");
          _scheduleNextHeartbeat(seconds);
          return;
        }

        // ------------------------------------------------------
        // 2) SE AMBOS ESTÃƒÆ’O PAUSADOS
        // ------------------------------------------------------
        if (hbPausadoPorEntrega && hbPausadoPorVenda) {
          _log(
              "Ã¢Å¡Â Ã¯Â¸Â Ambos os heartbeats estÃƒÂ£o PAUSADOS Ã¢â€ â€™ Aguardando liberaÃƒÂ§ÃƒÂ£o.");
          _scheduleNextHeartbeat(seconds);
          return;
        }

        // ------------------------------------------------------
        // 3) SE USUÃƒÂRIO Ãƒâ€° APENAS MOTOBOY
        // ------------------------------------------------------
        if (isMotoboy && !isFornecedor) {
          if (!isMotoBoyOnline) {
            _log(
                "Ã¢Å¡Â Ã¯Â¸Â MotoBoy estÃƒÂ¡ offline Ã¢â€ â€™ nÃƒÂ£o enviar heartbeat.");
          } else if (hbPausadoPorVenda) {
            _log(
                "Ã¢Å¡Â Ã¯Â¸Â Heartbeat MotoBoy PAUSADO por venda do fornecedor.");
          } else {
            await chamaHeartbeat();
          }

          _scheduleNextHeartbeat(seconds);
          return;
        }

        // ------------------------------------------------------
        // 4) SE USUÃƒÂRIO Ãƒâ€° APENAS FORNECEDOR
        // ------------------------------------------------------
        if (!isMotoboy && isFornecedor) {
          if (!isFornecedorOnline) {
            _log(
                "Ã¢Å¡Â Ã¯Â¸Â Fornecedor estÃƒÂ¡ offline Ã¢â€ â€™ nÃƒÂ£o enviar heartbeat.");
          } else if (hbPausadoPorEntrega) {
            _log(
                "Ã¢Å¡Â Ã¯Â¸Â Heartbeat Fornecedor PAUSADO por entrega do motoboy.");
          } else {
            await chamaHeartbeat();
          }

          _scheduleNextHeartbeat(seconds);
          return;
        }

        // ------------------------------------------------------
        // 5) SE Ãƒâ€° AMBOS OS PERFIS
        // ------------------------------------------------------
        if (isMotoboy && isFornecedor) {
          _log(
              "Modo AMBOS ATIVOS Ã¢â€ â€™ Decision by chamaHeartbeat()");
          await chamaHeartbeat();
          _scheduleNextHeartbeat(seconds);
          return;
        }
      });
    } catch (e, st) {
      _log("ERRO ao agendar heartbeat: $e\n$st");
    }
  }

  void pausarHeartbeatFornecedor() {
    hbPausadoPorEntrega = true;
    _log(
        "Ã¢ÂÂ¸ HeartbeatF PAUSADO (Motoboy aceitou entrega)");
  }

  void pausarHeartbeatMotoBoy() {
    hbPausadoPorVenda = true;
    _log(
        "Ã¢ÂÂ¸ HeartbeatM PAUSADO (Fornecedor aceitou venda)");
  }

  void despausarHeartbeatFornecedor() {
    hbPausadoPorEntrega = false;
    _log("Ã¢â€“Â¶ HeartbeatF DESPAUSADO");
  }

  void despausarHeartbeatMotoBoy() {
    hbPausadoPorVenda = false;
    _log("Ã¢â€“Â¶ HeartbeatM DESPAUSADO");
  }

  Future<void> chamaHeartbeat() async {
    _log('--- chamaHeartbeat START ---');

    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      final pos = _locationService.ultimaPosicao;
      final latitude = pos?.latitude ?? -30.1165;
      final longitude = pos?.longitude ?? -51.1355;

      _log("Local atual: lat=$latitude lon=$longitude");

      final bool usuarioEhMotoboy = isMotoboy;
      final bool usuarioEhFornecedor = isFornecedor;

      // ============================================================
      // 1) SE SÃƒâ€œ MOTOBOY
      // ============================================================
      if (usuarioEhMotoboy && !usuarioEhFornecedor) {
        _log("Modo: SOMENTE MOTOBOY");
        if (!hbPausadoPorVenda && !_motoboyTrackingActive) {
          await _processaMotoboy(prefs, latitude, longitude);
        } else {
          _log("Heartbeat MotoBoy PAUSADO (hbPausadoPorVenda=true)");
        }

        return; // continuarÃƒÂ¡ no finally para reagendar
      }

      // ============================================================
      // 2) SE SÃƒâ€œ FORNECEDOR
      // ============================================================
      if (!usuarioEhMotoboy && usuarioEhFornecedor) {
        _log("Modo: SOMENTE FORNECEDOR");
        if (!hbPausadoPorEntrega) {
          await _processaFornecedor(prefs, latitude, longitude);
        } else {
          _log("Heartbeat Fornecedor PAUSADO (hbPausadoPorEntrega=true)");
        }

        return;
      }

      // ============================================================
      // 3) SE FOR AMBOS (MOTOBOY + FORNECEDOR)
      // ============================================================
      if (usuarioEhMotoboy && usuarioEhFornecedor) {
        _log("Modo: AMBOS OS PERFIS ATIVOS");

        // alternÃƒÂ¢ncia
        if (proximoEhFornecedor) {
          _log(
              "Ã¢â€ â€™ Tick atual: Fornecedor");

          if (!hbPausadoPorEntrega) {
            await _processaFornecedor(prefs, latitude, longitude);
          } else {
            _log("Fornecedor PAUSADO (hbPausadoPorEntrega=true)");
          }

          proximoEhFornecedor = false;
        } else {
          _log("Ã¢â€ â€™ Tick atual: Motoboy");

          if (!hbPausadoPorVenda && !_motoboyTrackingActive) {
            await _processaMotoboy(prefs, latitude, longitude);
          } else {
            _log("Motoboy PAUSADO (hbPausadoPorVenda=true)");
          }

          proximoEhFornecedor = true;
        }

        return;
      }
    } catch (e, st) {
      _log('ERRO em chamaHeartbeat: $e\n$st');
    } finally {
      _log(
          'Reagendando heartbeat (intervalo=$intervalo s)Ã¢â‚¬Â¦');
      _scheduleNextHeartbeat(intervalo);
      _log('--- chamaHeartbeat END ---');
    }
  }

  Future<void> _processaFornecedor(
      SharedPreferences prefs, double latitude, double longitude) async {
    _log(
        'Fornecedor detectado. Chamando API.sendHeartbeatFÃ¢â‚¬Â¦');

    final fornecedorDetails = await API.sendHeartbeatF(latitude, longitude);

    if (fornecedorDetails == null) {
      _log("ERRO: fornecedorDetails == null");
      return;
    }

    final temNovaVenda = fornecedorDetails.novaVenda != null;
    final novaVenda = fornecedorDetails.novaVenda;
    final itens = fornecedorDetails.itensVenda;

    _log('HeartbeatF OK: lojasNoRaio=${fornecedorDetails.lojasNoRaio}, '
        'idLoja=${fornecedorDetails.idLoja}, '
        'temNovaVenda=$temNovaVenda, '
        'novaVendaObj=${novaVenda != null}, '
        'itensVenda=${itens.length}');

    // ----------------------------------------------------------
    // 1) Processar nova venda SOMENTE se REAL e completa
    // ----------------------------------------------------------
    if (temNovaVenda && novaVenda != null && itens.isNotEmpty) {
      _log("Ã¢Å¾Â¡ Nova venda REAL detectada!");

      await prefs.setString('hora', novaVenda.hora);
      await prefs.setString('valor', novaVenda.valor);
      await prefs.setString('cliente', novaVenda.cliente);
      await prefs.setInt('idPed', novaVenda.idPed);
      await prefs.setInt('idAviso', novaVenda.idAviso);

      // Exibir aviso ao fornecedor (popup + som)
      await mostrarAvisoNovaVenda(novaVenda, itens);
    } else {
      _log("Nenhuma nova venda REAL. Nada serÃƒÂ¡ exibido.");
    }

    // ----------------------------------------------------------
    // 2) Atualiza SOMENTE a UI do fornecedor
    //    (nÃƒÂ£o interfere mais no deliveryData do motoboy)
    // ----------------------------------------------------------
    setState(() {
      lojasNoRaio = fornecedorDetails.lojasNoRaio;

      deliveryDataFornecedor = {
        'idLoja': fornecedorDetails.idLoja,
        'lojasNoRaio': fornecedorDetails.lojasNoRaio,
        // Se quiser adicionar mais informaÃƒÂ§ÃƒÂµes no futuro, coloque aqui.
      };
    });

    _log("Processamento Fornecedor concluÃƒÂ­do.");
  }

  Future<void> _trataNovaVenda(FornecedorHeartbeatResponse fornecedorDetails,
      SharedPreferences prefs) async {
    final novaVenda = fornecedorDetails.novaVenda!;
    _log("Nova venda detectada!");

    await prefs.setString('hora', novaVenda.hora);
    await prefs.setString('valor', novaVenda.valor);
    await prefs.setString('cliente', novaVenda.cliente);
    await prefs.setInt('idPed', novaVenda.idPed);
    await prefs.setInt('idAviso', novaVenda.idAviso);

    await mostrarAvisoNovaVenda(novaVenda, fornecedorDetails.itensVenda);
  }

  Future<void> _processaMotoboy(
      SharedPreferences prefs, double latitude, double longitude) async {
    _log(
        'Motoboy detectado. Chamando API.sendHeartbeatÃ¢â‚¬Â¦');

    final deliveryDetails = await API.sendHeartbeat(latitude, longitude);

    if (deliveryDetails == null) {
      _log("ERRO: deliveryDetails == null");
      return;
    }

    if (!mounted) return;

    _log('HeartbeatM OK: lojasNoRaio=${deliveryDetails.lojasNoRaio}, '
        'valor=${deliveryDetails.valor}, chamado=${deliveryDetails.chamado}');

    // --------------------------------------------------------------
    // 1) Nenhum chamado vÃƒÂ¡lido Ã¢â€ â€™ limpar UI motoboy
    // --------------------------------------------------------------
    if (deliveryDetails.chamado == null || deliveryDetails.chamado == 0) {
      _log(
          "Nenhum chamado vÃƒÂ¡lido (chamado=0). Limpando dados do motoboy.");

      setState(() {
        lojasNoRaio = deliveryDetails.lojasNoRaio;
        deliveryDataMotoboy = null;
      });

      return;
    }

    // --------------------------------------------------------------
    // 2) NÃƒÆ’O validar codigoConfirmacao aqui!
    //    Apenas mostrar a entrega. CÃƒÂ³digo sÃƒÂ³ importa na finalizaÃƒÂ§ÃƒÂ£o.
    // --------------------------------------------------------------
    _log(
        "Entrega recebida (chamado=${deliveryDetails.chamado}) Ã¢â€ â€™ exibindo ao motoboy.");
    hbPausadoPorEntrega = true;

    // --------------------------------------------------------------
    // 3) Parse seguro Ã¢â‚¬â€ SEM risco de null
    // --------------------------------------------------------------
    final valorSeguro = (deliveryDetails.valor ?? 0).toDouble();
    final distSeguro = (deliveryDetails.dist ?? 0).toDouble();
    final pesoSeguro = (deliveryDetails.peso ?? 0).toDouble();

    // --------------------------------------------------------------
    // 4) Atualizar dados do motoboy para exibir entrega
    // --------------------------------------------------------------
    setState(() {
      lojasNoRaio = deliveryDetails.lojasNoRaio;

      deliveryDataMotoboy = {
        'enderIN': deliveryDetails.enderIN ?? 'Desconhecido',
        'enderFN': deliveryDetails.enderFN ?? 'Desconhecido',
        'dist': distSeguro,
        'valor': valorSeguro,
        'peso': pesoSeguro,
        'chamado': deliveryDetails.chamado,
        'lojasNoRaio': deliveryDetails.lojasNoRaio,
        'fornecedor': deliveryDetails.fornecedor,
        'codigoRetirada': deliveryDetails.codigoRetirada,
        'codigoColeta': deliveryDetails.codigoColeta,
        'codigoConfirmacao': deliveryDetails.codigoConfirmacao,
      };
    });

    // --------------------------------------------------------------
    // 5) Enviar report apenas quando for um chamado novo
    // --------------------------------------------------------------
    final currentChamado = prefs.getInt('currentChamado');

    if (currentChamado != deliveryDetails.chamado) {
      _log(
          "Novo chamado detectado Ã¢â‚¬â€ atualizando currentChamado");

      await prefs.setInt('currentChamado', deliveryDetails.chamado ?? 0);

      final userId = prefs.getInt('idUser');
      if (userId != null) {
        _log(
            "Reportando visualizaÃƒÂ§ÃƒÂ£o ao servidorÃ¢â‚¬Â¦ userId=$userId");
        await API.reportViewToServer(userId, deliveryDetails.chamado);
      }
    } else {
      _log(
          "Chamado jÃƒÂ¡ processado anteriormente. Ignorando report.");
    }

    // --------------------------------------------------------------
    // 6) HeartbeatFornecedoR nÃƒÂ£o deve ser pausado aqui
    //    Apenas quando motoboy ACEITA a entrega.
    // --------------------------------------------------------------

    _log("Processamento Motoboy concluÃƒÂ­do.");
  }

  Future<void> mostrarAvisoNovaVenda(
    NovaVenda novaVenda,
    List<ItemVenda> itensVenda,
  ) async {
    if (!mounted || _dialogAberto) return;
    _dialogAberto = true;
    int segundosRestantes = 60;
    late Timer contagemRegressiva;

    Timer? timerSom;
    void iniciarSom() {
      tocarSomVenda();
      timerSom = Timer.periodic(
        const Duration(seconds: 8),
        (_) => tocarSomVenda(),
      );
    }

    void pararSom() {
      try {
        timerSom?.cancel();
        pararSomVenda();
      } catch (_) {}
    }

    iniciarSom();

    void fecharDialogo([bool recusado = false]) async {
      if (!_dialogAberto) return;
      pararSom();
      contagemRegressiva.cancel();
      Navigator.of(context, rootNavigator: true).pop();
      _dialogAberto = false;
      await _processarFechamentoDialogo(recusado);
    }

    contagemRegressiva = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        segundosRestantes--;
        if (segundosRestantes <= 0) {
          fecharDialogo(true);
        }
      },
    );

    await _exibirDialogoNovaVenda(
        novaVenda, itensVenda, segundosRestantes, fecharDialogo);

    contagemRegressiva.cancel();
    pararSom();
    _dialogAberto = false;
    _log("DiÃƒÂ¡logo de venda fechado.");
  }

  Future<void> _processarFechamentoDialogo(bool recusado) async {
    final prefs = await SharedPreferences.getInstance();
    final idAviso = prefs.getInt('idAviso');
    final idPed = prefs.getInt('idPed');

    if (!isFornecedor) {
      handleDeliveryResponse(!recusado);
      return;
    }

    if (recusado) {
      _log("Fornecedor recusou venda.");
      return;
    }

    _log("Fornecedor ACEITOU nova venda.");
    hbPausadoPorVenda = true;
    _log(
        "Ã¢ÂÂ¸ Heartbeat do Motoboy pausado (hbPausadoPorVenda=true)");

    if (idAviso != null && idPed != null) {
      _log(
          "Enviando confirmaÃƒÂ§ÃƒÂ£o da venda: idAviso=$idAviso, idPed=$idPed");
      await API.fornecedorConfirmou(idAviso, idPed);
    } else {
      _log("ERRO: idAviso ou idPed ausentes no SharedPreferences");
    }
  }

  Future<void> _exibirDialogoNovaVenda(
    NovaVenda novaVenda,
    List<ItemVenda> itensVenda,
    int segundosRestantes,
    void Function([bool]) fecharDialogo,
  ) {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: const [
                  Icon(Icons.shopping_cart, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Nova Venda!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${novaVenda.cliente}'),
                  Text('Valor: ${novaVenda.valor}'),
                  Text('Hora: ${novaVenda.hora}'),
                  const SizedBox(height: 8),
                  const Text('Itens do Pedido:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...itensVenda.map(
                      (item) => Text("- ${item.produto} x${item.quantidade}")),
                  const SizedBox(height: 12),
                  Text(
                    'Ã¢ÂÂ³ Fechando em $segundosRestantes s',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => fecharDialogo(true),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => fecharDialogo(false),
                  child: const Text('OK', style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> handleDeliveryResponse(bool accept) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    final dadosOferta = deliveryDataMotoboy;

    final int? deliveryId = dadosOferta?['chamado'];

    if (userId == null || deliveryId == null) {
      setState(() {
        statusMessage = "Erro: Dados da entrega nÃ£o encontrados.";
      });
      return;
    }

    _log(
        "Ã°Å¸â€œÂ¦ Respondendo entrega $deliveryId | accept=$accept");

    final sucesso = await API.respondToDelivery(userId, deliveryId, accept);

    if (!sucesso) {
      setState(() {
        statusMessage = "Erro ao comunicar resposta ao servidor.";
      });
      return;
    }

    // -----------------------------
    // Ã°Å¸â€Â´ CASO RECUSA
    // -----------------------------
    if (!accept) {
      setState(() {
        statusMessage = "Entrega recusada.";
        deliveryDataMotoboy = null;
        hasAcceptedDelivery = false;
      });

      hbPausadoPorEntrega = false;
      _log(
          "Ã¢Å“â€ Entrega recusada Ã¢â€ â€™ heartbeat liberado.");
      return;
    }

    // -----------------------------
    // Ã°Å¸Å¸Â¢ CASO ACEITE
    // -----------------------------
    _log(
        "Ã¢Å“â€¦ Entrega aceita. Buscando entrega ativa...");

    var entrega = await EntregaService.carregarEntregaAtiva();

    if (entrega == null) {
      _log(
          "Entrega ativa ainda indisponÃ­vel. Usando dados da oferta aceita.");

      entrega = EntregaAtiva(
        idPedido: deliveryId,
        codigoRetirada: (dadosOferta?['codigoRetirada'] ??
                dadosOferta?['codigoColeta'] ??
                '')
            .toString(),
        fornecedor: (dadosOferta?['fornecedor'] ?? '').toString(),
        enderecoFornecedor: (dadosOferta?['enderIN'] ?? '').toString(),
        codigoColeta: dadosOferta?['codigoColeta']?.toString(),
        status: 1,
      );
    }

    setState(() {
      entregaAtiva = entrega;
      valorEntregaAtual = (dadosOferta?['valor'] is num)
          ? (dadosOferta?['valor'] as num).toDouble()
          : double.tryParse(dadosOferta?['valor']?.toString() ?? '');
      hasAcceptedDelivery = true;
      hasPickedUp = false;
      deliveryCompleted = false;
      erroCodigoCliente = null;
      enviandoCodigoCliente = false;
      _codigoClienteController.clear();
      statusMessage = "Entrega aceita. Dirija-se ao fornecedor.";

      deliveryDataMotoboy = null; // limpa oferta
    });

    hbPausadoPorEntrega = true;

    _log(
        "Ã°Å¸â€Â CÃ³digo de retirada carregado: ${entrega.codigoRetirada}");
  }

  Future<void> handleDeliveryCompleted() async {
    _log("Entrega ConcluÃƒÂ­da acionada.");

    // 1. Mostrar tela de cÃƒÂ³digo
    final codigoCliente = _codigoClienteController.text.trim();

    if (codigoCliente.length != 3 || int.tryParse(codigoCliente) == null) {
      setState(() {
        erroCodigoCliente = "Digite um codigo valido de 3 digitos";
      });
      return;
    }

    // 2. CÃƒÂ³digo OK Ã¢â€ â€™ efetivar entrega
    _log("CÃƒÂ³digo verificado! Enviando encerramento...");

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');

    setState(() {
      enviandoCodigoCliente = true;
      erroCodigoCliente = null;
    });

    bool ok = await API.notifyDeliveryCompleted(
      idPedido: entregaAtiva?.idPedido,
      idMotoboy: userId,
      codigo: codigoCliente,
    );

    if (!mounted) return;

    if (ok) {
      final valorFinal = API.ultimoValorEntrega ?? valorEntregaAtual ?? 0;
      final valorGanho = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
          .format(valorFinal);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entrega concluÃ­da com sucesso!")),
      );
      _log("Entrega finalizada com sucesso.");

      // ------------------------------------------------------
      // Ã°Å¸â€Â¥ NOVO: Entrega concluÃƒÂ­da Ã¢â€ â€™ liberar HeartbeatFornecedor
      // ------------------------------------------------------
      hbPausadoPorEntrega = false;
      _log(
          "Ã¢Å“â€ Entrega concluÃƒÂ­da Ã¢â€ â€™ HeartbeatFornecedor retomado");

      // opcional: limpar cÃƒÂ³digo salvo
      prefs.remove('codigoConfirmacao');

      setState(() {
        hasAcceptedDelivery = false;
        hasPickedUp = false;
        deliveryCompleted = true;
        deliveryData = null;
        deliveryDataMotoboy = null;
        entregaAtiva = null;
        erroCodigoCliente = null;
        enviandoCodigoCliente = false;
        _codigoClienteController.clear();
        statusMessage = "Voce ganhou $valorGanho";
      });
    } else {
      setState(() {
        enviandoCodigoCliente = false;
        erroCodigoCliente = "Codigo do cliente invalido.";
      });
      _log("Falha no encerramento da entrega.");
    }
  }

  void handleWaitingForNewDelivery() {
    setState(() {
      deliveryData = null;
      statusMessage = "Aguardando novas entregas...";
      hasPickedUp = false;
      deliveryCompleted = false;
      hasAcceptedDelivery = false;
    });
  }

  void handlePickedUp() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    final idPedido = entregaAtiva?.idPedido;

    _log(
        "Registrando chegada no fornecedor idPedido=$idPedido idMotoboy=$userId");

    final codigoColeta =
        entregaAtiva?.codigoColeta ?? entregaAtiva?.codigoRetirada;

    bool success = await API.notifyPickedUp(
      idPedido: idPedido,
      idMotoboy: userId,
      codigo: codigoColeta,
    );

    if (success) {
      setState(() {
        hasPickedUp = true;
        statusMessage = "Peguei a encomenda com o fornecedor.";
        deliveryCompleted = false;
        erroCodigoCliente = null;
        enviandoCodigoCliente = false;
        _codigoClienteController.clear();
      });
    } else {
      setState(() {
        statusMessage = "Falha ao registrar a chegada no fornecedor.";
      });
    }
  }

  Future<void> updateSaldo() async {
    if (isSaldoAtualizado) return;
    print("Iniciando atualizaÃƒÂ§ÃƒÂ£o do saldo");
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    if (userId == null) return;

    try {
      print("[Saldo] request_started");
      final raw = await API.saldo(userId); // ex.: "123" ou "R$ 123,45"
      print("[Saldo] response_processed=true");

      final limpo =
          raw.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.').trim();

      final valor = double.tryParse(limpo) ?? 0.0;
      print("Saldo parseado: $valor");

      if (!mounted) return;
      setState(() {
        saldoNum = valor;
        saldo =
            NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
        isSaldoAtualizado = true;
      });
    } catch (e) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      if (!mounted) return;
      setState(() {
        saldoNum = 0.0;
        saldo = 'R\$ 0,00';
      });
    } finally {
      print(
          "AtualizaÃƒÂ§ÃƒÂ£o do saldo concluÃƒÂ­da");
    }
  }

  final AudioPlayer _playerAviso = AudioPlayer();

  void pararSomVenda() {
    try {
      _playerAviso.stop();
    } catch (_) {}
  }

  Future<void> _carregarOnlineStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final perfilFornecedor = prefs.getBool('isFornecedor') ?? false;
    final moto = await OnlineStatusService.getMotoStatus();
    final fornecedor = perfilFornecedor
        ? await OnlineStatusService.getFornecedorStatus()
        : false;

    if (!mounted) return;
    setState(() {
      isMotoBoyOnline = false;
      if (moto) {
        print(
            "[HomePage] Status online persistido; tracking aguardando confirmacao");
      }
      isFornecedorOnline = fornecedor;
    });

    print("[HomePage] MotoBoy Online? $isMotoBoyOnline");
    print("[HomePage] Fornecedor Online? $isFornecedorOnline");
  }

  Future<void> _carregarFavoritosRecebidos() async {
    print('[PerfilEntregador] carregamento_iniciado');
    final id = userId;
    if (id == null || id <= 0) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      return;
    }
    print('[PerfilEntregador] carregamento_iniciado');
    print('[PerfilEntregador] chamando_api');
    try {
      final data = await API.favoritosRecebidos(id);
      final recebido = data['favoritosRecebidos'];
      final quantidadeRaw = recebido is Map ? recebido['quantidade'] : 0;
      final quantidade = quantidadeRaw is num
          ? quantidadeRaw.toInt()
          : int.tryParse('$quantidadeRaw') ?? 0;
      final nome =
          recebido is Map ? recebido['nomeEmpresa']?.toString().trim() : null;

      print('[PerfilEntregador] status=200');
      print('[PerfilEntregador] quantidade=$quantidade');
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
      if (!mounted) return;
      setState(() {
        _quantidadeFavoritosRecebidos = quantidade;
        _nomeEmpresaFavorita = nome != null && nome.isNotEmpty ? nome : null;
      });
      print('[PerfilEntregador] estado_atualizado');
    } catch (error) {
      debugPrint('[Sanitized] sensitive_details_suppressed=true');
    }
  }

  Future<void> executarHeartbeat() async {
    _log(
        "Ã°Å¸â€Â¥ executarHeartbeat() chamado.");

    // =========================================================
    // Ã¢â€ºâ€ 1) PAUSA GLOBAL DO MOTOBOY ENQUANTO ELE ESTÃƒÂ ANALISANDO ENTREGA
    // =========================================================
    if (isMotoboy && hbPausadoPorEntrega) {
      _log(
          "Ã¢â€ºâ€ Heartbeat Motoboy PAUSADO (aguardando decisÃƒÂ£o do motoboy)");
      agendarProximoHeartbeat();
      return;
    }

    // =========================================================
    // 1) UsuÃƒÂ¡rio ÃƒÂ© AMBOS
    // =========================================================
    if (isMotoboy && isFornecedor) {
      // Ã°Å¸â€˜â€° Se Motoboy estÃƒÂ¡ em entrega Ã¢â€ â€™ PAUSAR Fornecedor
      if (hbPausadoPorEntrega) {
        _log(
            "Ã¢â€ºâ€ Heartbeat Fornecedor PAUSADO por entrega do Motoboy.");
        await chamaHeartbeatMotoboy();
        agendarProximoHeartbeat();
        return;
      }

      // Ã°Å¸â€˜â€° Se Fornecedor estÃƒÂ¡ em venda Ã¢â€ â€™ PAUSAR Motoboy
      if (hbPausadoPorVenda) {
        _log(
            "Ã¢â€ºâ€ Heartbeat Motoboy PAUSADO por venda do Fornecedor.");
        await chamaHeartbeatFornecedor();
        agendarProximoHeartbeat();
        return;
      }

      // Ã°Å¸â€˜â€° AlternÃƒÂ¢ncia normal
      if (proximoEhFornecedor) {
        _log(
            "Heartbeat Ã¢â€ â€™ Fornecedor (alternÃƒÂ¢ncia)");
        await chamaHeartbeatFornecedor();
        proximoEhFornecedor = false;
      } else {
        _log(
            "Heartbeat Ã¢â€ â€™ Motoboy (alternÃƒÂ¢ncia)");
        await chamaHeartbeatMotoboy();
        proximoEhFornecedor = true;
      }

      agendarProximoHeartbeat();
      return;
    }

    // =========================================================
    // 2) Apenas FORNECEDOR
    // =========================================================
    if (isFornecedor) {
      await chamaHeartbeatFornecedor();
      agendarProximoHeartbeat();
      return;
    }

    // =========================================================
    // 3) Apenas MOTOBOY
    // =========================================================
    if (isMotoboy) {
      await chamaHeartbeatMotoboy();
      agendarProximoHeartbeat();
      return;
    }
  }

  void agendarProximoHeartbeat() {
    _operationalController.cancelHeartbeatTimer();

    if (isMotoboy && !isFornecedor) {
      _operationalController.cancelHeartbeatTimer();
      return;
    }
    _log(
        "Ã¢ÂÂ³ Agendando prÃƒÂ³ximo heartbeat em $intervalo segundos...");

    _operationalController.scheduleHeartbeat(Duration(seconds: intervalo), () {
      executarHeartbeat();
    });
  }

  Future<void> chamaHeartbeatFornecedor() async {
    try {
      await _processaFornecedorComLatLong();
    } catch (e, st) {
      _log("ERRO chamaHeartbeatFornecedor: $e\n$st");
    }
  }

  Future<void> chamaHeartbeatMotoboy() async {
    try {
      await _processaMotoboyComLatLong();
    } catch (e, st) {
      _log("ERRO chamaHeartbeatMotoboy: $e\n$st");
    }
  }

  Future<void> _processaFornecedorComLatLong() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final pos = _locationService.ultimaPosicao;
    final latitude = pos?.latitude ?? -30.1165;
    final longitude = pos?.longitude ?? -51.1355;

    await _processaFornecedor(prefs, latitude, longitude);
  }

  Future<void> _processaMotoboyComLatLong() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final pos = _locationService.ultimaPosicao;
    final latitude = pos?.latitude ?? -30.1165;
    final longitude = pos?.longitude ?? -51.1355;

    await _processaMotoboy(prefs, latitude, longitude);
  }

// ===========================================================
// VERSÃƒÆ’O 1.5.0 - 2025-12-06
// ImplementaÃƒÂ§ÃƒÂ£o do Card de Entrega Ativa com CÃƒÂ³digo de Retirada
// ===========================================================
  Widget buildEntregaAtivaCard() {
    _log(
        "Ã°Å¸â€œÅ’ [v1.5.0] buildEntregaAtivaCard() renderizando");

    if (entregaAtiva == null) {
      return SizedBox.shrink();
    }

    if (hasPickedUp && !deliveryCompleted) {
      return Card(
        elevation: 6,
        color: Colors.green.shade50,
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "FINALIZAR ENTREGA",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Pedido: #${entregaAtiva!.idPedido}",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              _buildCodigoClientePanel(),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 6,
      color: Colors.orange.shade50,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "ENTREGA ACEITA",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Pedido: #${entregaAtiva!.idPedido}",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            if (!hasPickedUp) ...[
              if (entregaAtiva!.codigoRetirada.isNotEmpty) ...[
                Text(
                  "Ã°Å¸â€Â CÃ“DIGO DE RETIRADA",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  entregaAtiva!.codigoRetirada,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Informe este cÃ³digo ao fornecedor para retirar o produto.",
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  "Codigo de retirada ainda nao recebido.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Nao use o codigo do cliente nesta etapa.",
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 20),
              Text(
                "Ã°Å¸ÂÂª ${entregaAtiva!.fornecedor}",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(entregaAtiva!.enderecoFornecedor),
              if (entregaAtiva!.codigoColeta != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    "CÃ³digo de coleta: ${entregaAtiva!.codigoColeta}",
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              if (hasAcceptedDelivery && !hasPickedUp) ...[
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: handlePickedUp,
                  child: const Text('Cheguei no Fornecedor'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(180, 44),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
            if (hasPickedUp && !deliveryCompleted) ...[
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "CODIGO DO CLIENTE",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Informe o codigo recebido do cliente para finalizar.",
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: _codigoClienteController,
                      enabled: !enviandoCodigoCliente,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        errorText: erroCodigoCliente,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: enviandoCodigoCliente
                          ? null
                          : handleDeliveryCompleted,
                      child: enviandoCodigoCliente
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirmar Codigo do Cliente'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(220, 44),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntregaAtivaSection() {
    if (entregaAtiva == null) return const SizedBox();

    return buildEntregaAtivaCard();
  }

  Widget _buildCodigoClientePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "CODIGO DO CLIENTE",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Informe o codigo recebido do cliente para finalizar.",
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 14),
          TextField(
            controller: _codigoClienteController,
            enabled: !enviandoCodigoCliente,
            keyboardType: TextInputType.number,
            maxLength: 3,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              counterText: '',
              errorText: erroCodigoCliente,
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 14),
          ElevatedButton(
            onPressed: enviandoCodigoCliente ? null : handleDeliveryCompleted,
            child: enviandoCodigoCliente
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirmar Codigo do Cliente'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(220, 44),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

// ===========================================================
// VERSÃƒÆ’O 1.5.2 - 2026-02-15
// CorreÃƒÂ§ÃƒÂ£o: buildOfertaMotoboyCard nunca retorna null
// Exibe oferta de entrega antes da aceitaÃƒÂ§ÃƒÂ£o
// ===========================================================

  Widget buildOfertaMotoboyCard() {
    if (deliveryDataMotoboy == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Ã°Å¸Å¡Å¡ NOVA ENTREGA DISPONÃVEL",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Text("Origem: ${deliveryDataMotoboy!['enderIN']}"),
            Text("Destino: ${deliveryDataMotoboy!['enderFN']}"),
            const SizedBox(height: 8),
            Text("DistÃ¢ncia: ${deliveryDataMotoboy!['dist']} km"),
            Text("Valor: R\$ ${deliveryDataMotoboy!['valor']}"),
            Text("Peso: ${deliveryDataMotoboy!['peso']} kg"),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _log("Motoboy clicou em RECUSAR");
                    handleDeliveryResponse(false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 45),
                  ),
                  child: const Text("Recusar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _log("Motoboy clicou em ACEITAR");
                    handleDeliveryResponse(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 45),
                  ),
                  child: const Text("Aceitar"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaldoSection() {
    if (!(isMotoboy || isFornecedor)) {
      return const SizedBox();
    }

    return Column(
      children: [
        Text(
          "Saldo $saldo",
          style: const TextStyle(fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMotoboySection() {
    if (!isMotoboy) return const SizedBox();

    return Column(
      children: [
        Text(
          'Lojas Abertas: $lojasNoRaio',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 10),
        if (entregaAtiva == null &&
            deliveryDataMotoboy != null &&
            deliveryDataMotoboy!.containsKey('chamado'))
          _buildDeliveryDetails(),
        if (entregaAtiva != null) buildEntregaAtivaCard(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFornecedorSection() {
    if (!isFornecedor) return const SizedBox();
    return const SizedBox(height: 10);
  }

  Widget _buildMotoOnlineButton() {
    if (!isMotoboy) return const SizedBox();

    return ElevatedButton(
      onPressed: () async {
        final novoStatus = !isMotoBoyOnline;
        await _setMotoboyOnline(novoStatus);
      },
      child: Text(
        isMotoBoyOnline
            ? "Passar para OffLine (MotoBoy)"
            : "Passar para OnLine (MotoBoy)",
      ),
    );
  }

  Widget _buildFornecedorOnlineButton() {
    if (!isFornecedor) return const SizedBox();

    return ElevatedButton(
      onPressed: () async {
        final novoStatus = !isFornecedorOnline;
        await OnlineStatusService.setFornecedorStatus(novoStatus);
        setState(() => isFornecedorOnline = novoStatus);
      },
      child: Text(
        isFornecedorOnline
            ? "Passar para OffLine (Fornecedor)"
            : "Passar para OnLine (Fornecedor)",
      ),
    );
  }

  Widget _buildOfertaSection() {
    if (entregaAtiva == null && deliveryDataMotoboy != null) {
      return buildOfertaMotoboyCard();
    }
    return const SizedBox();
  }
}
