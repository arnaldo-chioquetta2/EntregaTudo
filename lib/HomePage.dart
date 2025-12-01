import 'dart:async';
import 'dart:io';
import 'resgate_page.dart';
import 'settingsPage.dart';
import 'package:intl/intl.dart';
import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'features/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:entregatudo/utils/sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entregatudo/utils/online_status_service.dart';

// 1.4.4 MotoBoy e Fornecedor ao mesmo tempo
// 1.4.3 Modo offline para MotoBoy e Fornecedor
// 1.4.0 Correção estavam sendo mostradas vendas falsas
// 1.3.9 Fornecedor recebe aviso pelo App sobre a venda
// 1.2.4 Conserto do link para as configurações

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  Map<String, dynamic>? deliveryData;
  String? statusMessage;
  bool hasPickedUp = false;
  bool deliveryCompleted = false;
  bool hasAcceptedDelivery = false;
  String saldo = 'R\$ 0,00';
  double saldoNum = 0.0;
  final LocationService _locationService = LocationService();
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
  bool isMotoBoyOnline = false;
  bool isFornecedorOnline = false;

  void _toggleMotoBoyOnline() {
    setState(() => isMotoBoyOnline = !isMotoBoyOnline);
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
      print('[LOG ${_ts()}] ERRO ao criar arquivo de log: $e');
    }
  }

  Future<void> _log(String msg) async {
    final line = '[HomePage ${_ts()}] $msg';
    print(line);

    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString('$line\n', mode: FileMode.append);
    } catch (e) {
      print('[LOG ${_ts()}] ERRO ao gravar no arquivo: $e');
    }
  }

  late Future<void> _initFuture;

  int intervalo = kIsWeb ? 5 : 1;

  @override
  void initState() {
    super.initState();
    _initLogFile();

    // 🔥 Carrega estados de online/offline
    _carregarOnlineStatus();

    // 🔥 Continua fluxo normal
    _initFuture = _verificarLoginOuCadastro();
  }

  Future<void> _verificarLoginOuCadastro() async {
    if (isCheckingLogin) {
      _log('Ignorado: verificação já em andamento.');
      return;
    }
    isCheckingLogin = true;
    _log("Iniciando verificação de login ou cadastro");

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('idUser');

      // ============================================================
      // PERFIS – O usuário pode ser SOMENTE motoboy OU fornecedor
      // ============================================================
      isFornecedor = prefs.getBool('isFornecedor') ?? false;
      isMotoboy = prefs.getBool('isMotoboy') ?? false;

      _log("Perfis carregados → Motoboy=$isMotoboy | Fornecedor=$isFornecedor");

      // ============================================================
      // VERIFICA LOGIN
      // ============================================================
      if (userId == null || userId == 0) {
        _log("Usuário não logado. Indo para tela de registro.");
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

      // ============================================================
      // CARREGAR ESTADO ONLINE/OFFLINE
      // ============================================================
      isMotoBoyOnline = await OnlineStatusService.getMotoStatus();
      isFornecedorOnline = await OnlineStatusService.getFornecedorStatus();

      _log(
          "OnlineStatus → MotoBoy=$isMotoBoyOnline | Fornecedor=$isFornecedorOnline");

      // ============================================================
      // PERMISSÕES DE LOCALIZAÇÃO
      // ============================================================
      _log("Solicitando permissões de localização…");
      _locationService.requestPermissions();

      // ============================================================
      // ATUALIZAR SALDO
      // ============================================================
      _log("Atualizando saldo...");
      await updateSaldo();

      // ============================================================
      // AGENDAR HEARTBEAT
      // ============================================================
      _log("Agendando heartbeat (intervalo=$intervalo s)...");
      _scheduleNextHeartbeat(intervalo);

      _log("Verificação concluída com sucesso.");
    } catch (e, st) {
      _log('ERRO em _verificarLoginOuCadastro: $e\n$st');
    } finally {
      isCheckingLogin = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teletudo App - Entregas'),
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

            // 🔥 AQUI AGORA NÃO USA MAIS FutureBuilder<bool>
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 👉 AQUI CONTINUA O RESTANTE DO SEU CÓDIGO,
                // blocos de motoboy, fornecedor, botões, tudo igual

                // ------------------ PERFIL MOTOBOY ------------------
                if (isMotoboy) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Lojas Abertas: $lojasNoRaio',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsPage()),
                      );
                    },
                    child: const Text('Configurações'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(150, 40),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  if (deliveryData != null && deliveryData!.isNotEmpty)
                    _buildDeliveryDetails(),
                  if (deliveryData == null &&
                      (deliveryCompleted || !hasAcceptedDelivery)) ...[
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "Saldo $saldo",
                        style:
                            const TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: null,
                      child: const Text('Detalhes'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(150, 40),
                        backgroundColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: saldoNum > 0
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ResgatePage()),
                              );
                            }
                          : null,
                      child: const Text('Resgate'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(150, 40),
                        backgroundColor: Colors.grey,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  if (statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        statusMessage!,
                        style: const TextStyle(fontSize: 18, color: Colors.red),
                      ),
                    ),
                  if (hasAcceptedDelivery && !hasPickedUp)
                    ElevatedButton(
                      onPressed: handlePickedUp,
                      child: const Text('Cheguei no Fornecedor'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(150, 40),
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  if (hasPickedUp && !deliveryCompleted)
                    ElevatedButton(
                      onPressed: handleDeliveryCompleted,
                      child: const Text('Entrega Concluída'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(150, 40),
                        backgroundColor: Colors.green,
                      ),
                    ),
                ],

                // Espaço entre blocos caso seja ambos
                if (isMotoboy && isFornecedor) const SizedBox(height: 30),

                // ------------------ PERFIL FORNECEDOR ------------------
                if (isFornecedor) ...[
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "Saldo $saldo",
                      style: const TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: saldoNum > 0
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ResgatePage()),
                            );
                          }
                        : null,
                    child: const Text('Resgate'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(150, 40),
                      backgroundColor: Colors.grey,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // ---------------- BOTÃO ON/OFF – MOTOBOY ----------------
                if (isMotoboy) ...[
                  ElevatedButton(
                    onPressed: () async {
                      final novoStatus = !isMotoBoyOnline;
                      await OnlineStatusService.setMotoStatus(novoStatus);

                      if (!novoStatus && userId != null) {
                        await API.motoOff(userId!);
                      }

                      setState(() => isMotoBoyOnline = novoStatus);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 45),
                      backgroundColor: isMotoBoyOnline
                          ? const Color(0xFFF57C00)
                          : const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isMotoBoyOnline
                          ? "Passar para OffLine (MotoBoy)"
                          : "Passar para OnLine (MotoBoy)",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!isMotoBoyOnline)
                    const Text(
                      "Você está OffLine (MotoBoy)",
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  const SizedBox(height: 20),
                ],

                // ---------------- BOTÃO ON/OFF – FORNECEDOR ----------------
                if (isFornecedor) ...[
                  ElevatedButton(
                    onPressed: () async {
                      final novoStatus = !isFornecedorOnline;
                      await OnlineStatusService.setFornecedorStatus(novoStatus);

                      if (!novoStatus) {
                        await API.fornecedorOff(idLoja: idLoja);
                      }

                      setState(() => isFornecedorOnline = novoStatus);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 45),
                      backgroundColor: isFornecedorOnline
                          ? const Color(0xFF8E24AA)
                          : const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isFornecedorOnline
                          ? "Passar para OffLine (Fornecedor)"
                          : "Passar para OnLine (Fornecedor)",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!isFornecedorOnline)
                    const Text(
                      "Você está OffLine (Fornecedor)",
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  const SizedBox(height: 20),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    // Segurança total contra campos faltando
    final enderIN = deliveryData?['enderIN'] ?? 'Desconhecido';
    final enderFN = deliveryData?['enderFN'] ?? 'Desconhecido';

    final distRaw = deliveryData?['dist'];
    final valorRaw = deliveryData?['valor'];

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

            // ------------------ DISTÂNCIA ------------------
            ListTile(
              leading: const Icon(Icons.map),
              title: Text(
                dist != null
                    ? 'Distância: ${dist.toStringAsFixed(1)} km'
                    : 'Distância: --',
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

            // ------------------ BOTÕES ------------------
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
          'Agendando próximo heartbeat para $seconds s (cancelando anterior=${_timer != null})…');

      _timer?.cancel();

      _timer = Timer(Duration(seconds: seconds), () async {
        bool isOnline = true;

        // 🚀 Motoboy → respeita status do motoboy
        if (isMotoboy) {
          isOnline = await OnlineStatusService.getMotoStatus();
        }

        // 🚀 Fornecedor → respeita status do fornecedor
        if (isFornecedor) {
          isOnline = await OnlineStatusService.getFornecedorStatus();
        }

        // ❌ Se está offline → NÃO envia heartbeat
        if (!isOnline) {
          _log("Heartbeat NÃO enviado porque o usuário está OFFLINE.");
          _scheduleNextHeartbeat(seconds); // reagenda mesmo offline
          return;
        }

        // ✔ Envia heartbeat normal
        await chamaHeartbeat();
      });
    } catch (e, st) {
      _log('ERRO ao agendar heartbeat: $e\n$st');
    }
  }

  Future<void> chamaHeartbeat() async {
    _log('--- chamaHeartbeat START ---');
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      final pos = _locationService.ultimaPosicao;
      final latitude = pos?.latitude ?? -30.1165;
      final longitude = pos?.longitude ?? -51.1355;
      _log("Enviando local: lat=$latitude, lon=$longitude");

      final idLoja = prefs.getInt('idLoja');
      _log('idLoja em prefs: $idLoja (idLoja>0 => fornecedor)');

      final codConf = prefs.getInt('codigoConfirmacao');
      if (codConf != null) _log("Código de confirmação atual: $codConf");

      if (idLoja != null && idLoja > 0) {
        await _processaFornecedor(prefs, latitude, longitude);
      } else {
        await _processaMotoboy(prefs, latitude, longitude);
      }
    } catch (e, st) {
      _log('ERRO em chamaHeartbeat: $e\n$st');
    } finally {
      _log('Reagendando heartbeat (intervalo=$intervalo s)…');
      _scheduleNextHeartbeat(intervalo);
      _log('--- chamaHeartbeat END ---');
    }
  }

  Future<void> _processaFornecedor(
      SharedPreferences prefs, double latitude, double longitude) async {
    _log('Fornecedor detectado. Chamando API.sendHeartbeatF…');

    final fornecedorDetails = await API.sendHeartbeatF(latitude, longitude);

    if (fornecedorDetails == null) {
      _log("ERRO: fornecedorDetails == null");
      return;
    }

    _log('HeartbeatF OK: lojasNoRaio=${fornecedorDetails.lojasNoRaio}, '
        'idLoja=${fornecedorDetails.idLoja}, '
        'novaVenda=${fornecedorDetails.novaVenda != null}');

    if (fornecedorDetails.novaVenda != null) {
      await _trataNovaVenda(fornecedorDetails, prefs);
    }

    setState(() {
      lojasNoRaio = fornecedorDetails.lojasNoRaio;
      deliveryData = {'idLoja': fornecedorDetails.idLoja};
    });
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
    _log('Motoboy detectado. Chamando API.sendHeartbeat…');

    final deliveryDetails = await API.sendHeartbeat(latitude, longitude);

    if (deliveryDetails == null) {
      _log("ERRO: deliveryDetails == null");
      return;
    }

    _log('Heartbeat OK: lojasNoRaio=${deliveryDetails.lojasNoRaio}, '
        'valor=${deliveryDetails.valor}, chamado=${deliveryDetails.chamado}');

    /// ----------------------------------------------------
    /// 🔥 1) PROTEÇÃO CONTRA CHAMADO FALSO
    /// ----------------------------------------------------
    if (deliveryDetails.chamado == null || deliveryDetails.chamado == 0) {
      _log("⚠️ Nenhum chamado válido recebido (chamado=0). Ignorando.");

      setState(() {
        lojasNoRaio = deliveryDetails.lojasNoRaio;
        deliveryData = null;
      });

      return;
    }

    /// ----------------------------------------------------
    /// 🔥 2) PROTEÇÃO CONTRA codigoConfirmacao FALSO
    /// ----------------------------------------------------
    final codigo = prefs.getInt('codigoConfirmacao');

    if (codigo == null || codigo == 0) {
      _log(
          "⚠️ Nenhum codigoConfirmacao válido (codigo=$codigo). Ignorando venda.");
      return;
    }

    _log("Código de confirmação válido disponível: $codigo");

    /// ----------------------------------------------------
    /// ⭐ CORREÇÃO IMPORTANTE:
    /// Garantir que valor NUNCA seja null ou string
    /// ----------------------------------------------------
    final valorSeguro = (deliveryDetails.valor is num)
        ? deliveryDetails.valor
        : double.tryParse("${deliveryDetails.valor}") ?? 0.0;

    final distSeguro = (deliveryDetails.dist is num)
        ? deliveryDetails.dist
        : double.tryParse("${deliveryDetails.dist}") ?? 0.0;

    final pesoSeguro = (deliveryDetails.peso is num)
        ? deliveryDetails.peso
        : double.tryParse("${deliveryDetails.peso}") ?? 0.0;

    /// ----------------------------------------------------
    /// ✔ 3) ATUALIZAÇÃO DE UI — SOMENTE PARA VENDA REAL
    /// ----------------------------------------------------
    setState(() {
      lojasNoRaio = deliveryDetails.lojasNoRaio;
      deliveryData = {
        'enderIN': deliveryDetails.enderIN ?? 'Desconhecido',
        'enderFN': deliveryDetails.enderFN ?? 'Desconhecido',
        'dist': distSeguro,
        'valor': valorSeguro,
        'peso': pesoSeguro,
        'chamado': deliveryDetails.chamado,
        'lojasNoRaio': deliveryDetails.lojasNoRaio,
      };
    });

    /// ----------------------------------------------------
    /// ✔ 4) EVITA ENVIO DUPLICADO DE REPORT
    /// ----------------------------------------------------
    final currentChamado = prefs.getInt('currentChamado');

    if (currentChamado != deliveryDetails.chamado) {
      _log("Novo chamado detectado — atualizando currentChamado");

      await prefs.setInt('currentChamado', deliveryDetails.chamado ?? 0);

      final userId = prefs.getInt('idUser');
      if (userId != null) {
        _log("Reportando visualização ao servidor… userId=$userId");
        await API.reportViewToServer(userId, deliveryDetails.chamado);
      }
    } else {
      _log("Chamado já processado anteriormente. Ignorando report.");
    }
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

      // Só motoboy aceita/recusa entrega
      if (!isFornecedor) {
        if (recusado) {
          handleDeliveryResponse(false);
        } else {
          handleDeliveryResponse(true);
        }
        return;
      }

      // 👉 Fornecedor chegou aqui
      final prefs = await SharedPreferences.getInstance();
      final idAviso = prefs.getInt('idAviso');
      final idPed = prefs.getInt('idPed');

      if (idAviso != null && idPed != null) {
        _log("Enviando confirmação da venda: idAviso=$idAviso, idPed=$idPed");
        await API.fornecedorConfirmou(idAviso, idPed);
      } else {
        _log("ERRO: idAviso ou idPed ausentes no SharedPreferences");
      }
    }

    // void fecharDialogo([bool recusado = false]) async {
    //   if (!_dialogAberto) return;

    //   pararSom();
    //   contagemRegressiva.cancel();
    //   Navigator.of(context, rootNavigator: true).pop();
    //   _dialogAberto = false;

    //   // Só motoboy aceita/recusa entrega
    //   if (!isFornecedor) {
    //     if (recusado) {
    //       handleDeliveryResponse(false);
    //     } else {
    //       handleDeliveryResponse(true);
    //     }
    //     return;
    //   }

    //   // 👉 Fornecedor chegou aqui
    //   final prefs = await SharedPreferences.getInstance();
    //   final idAviso = prefs.getInt('idAviso');
    //   final idPed = prefs.getInt('idPed');

    //   if (idAviso != null && idPed != null) {
    //     _log("Enviando confirmação da venda: idAviso=$idAviso, idPed=$idPed");
    //     await API.fornecedorConfirmou(idAviso, idPed);
    //   } else {
    //     _log("ERRO: idAviso ou idPed ausentes no SharedPreferences");
    //   }
    // }

    contagemRegressiva = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        segundosRestantes--;
        if (segundosRestantes <= 0) {
          fecharDialogo(true); // timeout
        }
      },
    );

    await showDialog(
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
                    '⏳ Fechando em $segundosRestantes s',
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
    ).then((_) {
      contagemRegressiva.cancel();
      pararSom();
      _dialogAberto = false;
      _log("Diálogo de venda fechado.");
    });
  }

  void handleDeliveryResponse(bool accept) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('idUser');
    int? deliveryId = deliveryData?['chamado'];
    if (userId == null || deliveryId == null) {
      setState(() {
        statusMessage = "Erro: Dados da entrega não encontrados.";
      });
      return;
    }

    bool sucesso = await API.respondToDelivery(userId, deliveryId, accept);

    if (sucesso) {
      setState(() {
        hasAcceptedDelivery = accept;
        hasPickedUp = false;
        deliveryCompleted = !accept; // Se recusou, já marca como concluída
        statusMessage = accept
            ? "Entrega aceita. A caminho do fornecedor."
            : "Entrega recusada.";
        deliveryData = null;
      });
    } else {
      setState(() {
        statusMessage = "Erro ao comunicar resposta ao servidor.";
      });
    }
  }

  Future<void> handleDeliveryCompleted() async {
    _log("Entrega Concluída acionada.");

    // 1. Mostrar tela de código
    final resultado = await mostrarTelaCodigoConfirmacao();

    if (resultado != true) {
      _log("Entrega cancelada ou código incorreto.");
      return;
    }

    // 2. Código OK → efetivar entrega
    _log("Código verificado! Enviando encerramento...");

    bool ok = await API.notifyDeliveryCompleted();

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entrega concluída com sucesso!")),
      );
      _log("Entrega finalizada com sucesso.");

      // opcional: limpar código salvo
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.remove('codigoConfirmacao');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao concluir entrega.")),
      );
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
    bool success = await API.notifyPickedUp();
    if (success) {
      setState(() {
        hasPickedUp = true;
        statusMessage = "Peguei a encomenda com o fornecedor.";
        deliveryCompleted = false;
      });
    } else {
      setState(() {
        statusMessage = "Falha ao registrar a chegada no fornecedor.";
      });
    }
  }

  Future<void> updateSaldo() async {
    if (isSaldoAtualizado) return;
    print("Iniciando atualização do saldo");
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    if (userId == null) return;

    try {
      print("Buscando saldo para o usuário: $userId");
      final raw = await API.saldo(userId); // ex.: "123" ou "R$ 123,45"
      print("Saldo bruto da API: '$raw'");

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
      print("Erro ao atualizar saldo: $e");
      if (!mounted) return;
      setState(() {
        saldoNum = 0.0;
        saldo = 'R\$ 0,00';
      });
    } finally {
      print("Atualização do saldo concluída");
    }
  }

  Future<bool> mostrarTelaCodigoConfirmacao() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? codigoCorreto = prefs.getInt('codigoConfirmacao');

    if (codigoCorreto == null) {
      _log("ERRO: Nenhum código de confirmação salvo.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nenhum código disponível para confirmar."),
        ),
      );
      return false; // RETORNO OBRIGATÓRIO
    }

    TextEditingController controller = TextEditingController();
    String? erro;
    bool processando = false;

    /// resultado final que este método vai retornar
    bool resultado = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Confirmar Entrega"),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Informe o código recebido do cliente:"),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: "Código",
                        errorText: erro,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (processando)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                // CANCELAR
                TextButton(
                  onPressed: () {
                    resultado = false;
                    Navigator.pop(context);
                  },
                  child: const Text("Cancelar"),
                ),

                // RELATAR PROBLEMA
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Funcionalidade não disponível no momento.",
                        ),
                      ),
                    );
                  },
                  child: const Text("Relatar Problema"),
                ),

                // OK (VALIDAR CÓDIGO)
                TextButton(
                  onPressed: () {
                    final digitado = controller.text.trim();

                    if (digitado.length != 4 ||
                        int.tryParse(digitado) == null) {
                      setState(
                          () => erro = "Digite um código válido de 4 dígitos");
                      return;
                    }

                    if (digitado != codigoCorreto.toString()) {
                      setState(
                          () => erro = "Código incorreto. Tente novamente.");
                      return;
                    }

                    // Código correto
                    resultado = true;
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );

    return resultado; // <-- RETORNO FINAL
  }

  final AudioPlayer _playerAviso = AudioPlayer();

  void pararSomVenda() {
    try {
      _playerAviso.stop();
    } catch (_) {}
  }

  Future<void> _carregarOnlineStatus() async {
    final moto = await OnlineStatusService.getMotoStatus();
    final fornecedor = await OnlineStatusService.getFornecedorStatus();

    setState(() {
      isMotoBoyOnline = moto;
      isFornecedorOnline = fornecedor;
    });

    print("[HomePage] MotoBoy Online? $isMotoBoyOnline");
    print("[HomePage] Fornecedor Online? $isFornecedorOnline");
  }
}
