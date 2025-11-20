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
  bool isFornecedor = false;
  bool isSaldoAtualizado = false;
  bool isCheckingLogin = false;
  String _ts() => DateTime.now().toIso8601String();
  File? _logFile;
  bool _dialogAberto = false;

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
    _verificarLoginOuCadastro();
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
      final userId = prefs.getInt('idUser');
      isFornecedor = prefs.getBool('isFornecedor') ?? false;

      _log('Prefs: idUser=$userId, isFornecedor(pref)=$isFornecedor');

      // --- SIMULAÇÃO DE FORNECEDOR TESTE ---
      final email = prefs.getString('email') ?? '';
      final senha = prefs.getString('senha') ?? '';
      _log(
          'Credenciais em prefs: email="$email" senha="${'*' * senha.length}"');

      if (userId == null || userId == 0) {
        _log("Usuário não logado. Redirecionando para registro.");
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/register');
        return;
      }

      _log("Solicitando permissões de localização…");
      _locationService.requestPermissions();

      _log("Chamando updateSaldo para o usuário: $userId");
      await updateSaldo();

      _log("Agendando primeiro heartbeat (intervalo=$intervalo s)...");
      _scheduleNextHeartbeat(intervalo);

      _log("Verificação de login ou cadastro concluída");
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
              return const CircularProgressIndicator(); // Exibe um carregando
            } else if (snapshot.hasError) {
              return Text('Erro: ${snapshot.error}'); // Lida com erros
            }

            // Aqui, a verificação deve ser concluída
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isFornecedor) ...[
                  // Se for fornecedor, exibe apenas saldo e resgate
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
                ] else ...[
                  // Se não for fornecedor, exibe Lojas abertas e configurações
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
                  if (deliveryData != null) _buildDeliveryDetails(),
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    return Card(
      margin: EdgeInsets.all(20),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalhes da Entrega:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.location_on),
              title: Text('De: ${deliveryData!['enderIN']}'),
              subtitle: Text('Para: ${deliveryData!['enderFN']}'),
            ),
            ListTile(
              leading: Icon(Icons.map),
              title: Text('Distância: ${deliveryData!['dist']} km'),
            ),
            ListTile(
              leading: Icon(Icons.monetization_on, color: Colors.green),
              title: Text(
                  'Valor: R\$ ${deliveryData!['valor'].toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    handleDeliveryResponse(true);
                  },
                  child: Text(
                    'Aceitar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 40),
                    backgroundColor: Colors.green,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    handleDeliveryResponse(false);
                  },
                  child: Text(
                    'Recusar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 40),
                    backgroundColor: Colors.red,
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

    setState(() {
      lojasNoRaio = deliveryDetails.lojasNoRaio;
      deliveryData = {
        'enderIN': deliveryDetails.enderIN ?? 'Desconhecido',
        'enderFN': deliveryDetails.enderFN ?? 'Desconhecido',
        'dist': deliveryDetails.dist ?? 0.0,
        'valor': deliveryDetails.valor ?? 0.0,
        'peso': deliveryDetails.peso ?? 'Não Informado',
        'chamado': deliveryDetails.chamado,
        'lojasNoRaio': deliveryDetails.lojasNoRaio,
      };
    });

    final codigo = prefs.getInt('codigoConfirmacao');
    if (codigo != null) _log("Código de confirmação disponível: $codigo");

    final currentChamado = prefs.getInt('currentChamado');
    if (currentChamado != deliveryDetails.chamado) {
      await prefs.setInt('currentChamado', deliveryDetails.chamado ?? 0);

      final userId = prefs.getInt('idUser');
      if (userId != null) {
        await API.reportViewToServer(userId, deliveryDetails.chamado);
      }
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
}
