import 'dart:async';
import 'resgate_page.dart';
import 'settingsPage.dart';
import 'package:intl/intl.dart';
import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'features/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:entregatudo/models/delivery_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _verificarLoginOuCadastro();
  }

  Future<void> _verificarLoginOuCadastro() async {
    if (isCheckingLogin) return;
    isCheckingLogin = true;
    print("Iniciando verificação de login ou cadastro");
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    isFornecedor = prefs.getBool('isFornecedor') ?? false;
    if (userId == null || userId == 0) {
      print("Usuário não logado. Redirecionando para registro.");
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/register');
      isCheckingLogin = false;
      return;
    }
    _locationService.requestPermissions();
    _scheduleNextHeartbeat(2);
    print("Chamando updateSaldo para o usuário: $userId");
    await updateSaldo();
    print("Verificação de login ou cadastro concluída");
    isCheckingLogin = false;
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
          future: _verificarLoginOuCadastro(), // Chama a verificação
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
    _timer?.cancel();
    _timer = Timer(Duration(seconds: seconds), chamaHeartbeat);
  }

  Future<void> chamaHeartbeat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Position? pos = _locationService.ultimaPosicao;
    double latitude = pos?.latitude ?? -30.1165;
    double longitude = pos?.longitude ?? -51.1355;
    print("Enviando local: $latitude, $longitude");

    // Obtém o ID da loja para determinar o tipo de usuário
    int? idLoja = prefs.getInt('idLoja'); // Obtém o id_loja

    if (idLoja != null && idLoja > 0) {
      // Chama o sendHeartbeatF para fornecedores
      FornecedorHeartbeatResponse? fornecedorDetails =
          await API.sendHeartbeatF(latitude, longitude);

      if (fornecedorDetails != null) {
        // Processa os detalhes recebidos para fornecedores
        int lojasNoRaio = fornecedorDetails.lojasNoRaio;
        int idLoja = fornecedorDetails.idLoja;

        // Se houver nova venda, salve as informações
        if (fornecedorDetails.novaVenda != null) {
          NovaVenda novaVenda = fornecedorDetails.novaVenda!;
          await prefs.setString('hora', novaVenda.hora);
          await prefs.setString('valor', novaVenda.valor);
          await prefs.setString('cliente', novaVenda.cliente);
          await prefs.setInt('idPed', novaVenda.idPed);
          await prefs.setInt('idAviso', novaVenda.idAviso);
        }

        // Atualiza a UI com o número de lojas no raio
        setState(() {
          this.lojasNoRaio = lojasNoRaio;
          deliveryData = {
            'idLoja': idLoja,
            // Adicione outros dados que você deseja atualizar na UI
          };
        });

        print('Dados atualizados na UI com lojasNoRaio: $lojasNoRaio');
      } else {
        print("Erro ao receber dados de heartbeat do fornecedor");
      }
    } else {
      // Chama o sendHeartbeat para motoboys
      DeliveryDetails? deliveryDetails =
          await API.sendHeartbeat(latitude, longitude);

      if (deliveryDetails != null) {
        // Atualiza a variável lojasNoRaio aqui
        int lojasNoRaio = deliveryDetails.lojasNoRaio;
        double valorDelivery = deliveryDetails.valor ?? 0.0;
        int? currentChamado = prefs.getInt('currentChamado');

        print('Detalhes recebidos: $deliveryDetails');

        // Atualiza a UI com o número de lojas no raio
        setState(() {
          this.lojasNoRaio = lojasNoRaio; // Atualizando a variável de estado
          deliveryData = {
            'enderIN': deliveryDetails.enderIN ?? 'Desconhecido',
            'enderFN': deliveryDetails.enderFN ?? 'Desconhecido',
            'dist': deliveryDetails.dist ?? 0.0,
            'valor': valorDelivery,
            'peso': deliveryDetails.peso ?? 'Não Informado',
            'chamado': deliveryDetails.chamado,
            'lojasNoRaio': lojasNoRaio,
          };
        });

        print('Dados atualizados na UI com lojasNoRaio: $lojasNoRaio');

        // Se quiser reportar a visualização, pode fazer isso aqui
        if (currentChamado != deliveryDetails.chamado) {
          await prefs.setInt('currentChamado', deliveryDetails.chamado ?? 0);
          int? userId = prefs.getInt('idUser');
          if (userId != null) {
            await API.reportViewToServer(userId, deliveryDetails.chamado);
            print(
                "Visualização reportada: chamado = ${deliveryDetails.chamado}, userId = $userId");
          }
        }
      } else {
        print("Erro ao receber dados de heartbeat do motoboy");
      }
    }

    // Lógica de agendamento do próximo heartbeat
    _scheduleNextHeartbeat(
        60); // A lógica de intervalo pode ser ajustada conforme necessário
  }

  // Future<void> chamaHeartbeat() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   Position? pos = _locationService.ultimaPosicao;
  //   double latitude = pos?.latitude ?? -30.1165;
  //   double longitude = pos?.longitude ?? -51.1355;
  //   print("Enviando local: $latitude, $longitude");

  //   DeliveryDetails? deliveryDetails =
  //       await API.sendHeartbeat(latitude, longitude);

  //   if (deliveryDetails != null) {
  //     // Atualiza a variável lojasNoRaio aqui
  //     int lojasNoRaio = deliveryDetails.lojasNoRaio;
  //     double valorDelivery = deliveryDetails.valor ?? 0.0;
  //     int? currentChamado = prefs.getInt('currentChamado');

  //     print('Detalhes recebidos: $deliveryDetails');

  //     // Atualiza a UI com o número de lojas no raio
  //     setState(() {
  //       this.lojasNoRaio = lojasNoRaio; // Atualizando a variável de estado
  //       deliveryData = {
  //         'enderIN': deliveryDetails.enderIN ?? 'Desconhecido',
  //         'enderFN': deliveryDetails.enderFN ?? 'Desconhecido',
  //         'dist': deliveryDetails.dist ?? 0.0,
  //         'valor': valorDelivery,
  //         'peso': deliveryDetails.peso ?? 'Não Informado',
  //         'chamado': deliveryDetails.chamado,
  //         'lojasNoRaio': lojasNoRaio,
  //       };
  //     });

  //     print('Dados atualizados na UI com lojasNoRaio: $lojasNoRaio');

  //     // Se quiser reportar a visualização, pode fazer isso aqui
  //     if (currentChamado != deliveryDetails.chamado) {
  //       await prefs.setInt('currentChamado', deliveryDetails.chamado ?? 0);
  //       int? userId = prefs.getInt('idUser');
  //       if (userId != null) {
  //         await API.reportViewToServer(userId, deliveryDetails.chamado);
  //         print(
  //             "Visualização reportada: chamado = ${deliveryDetails.chamado}, userId = $userId");
  //       }
  //     }

  //     int nextInterval = (deliveryDetails.modo ?? 3) == 3 ? 60 : 10;
  //     _scheduleNextHeartbeat(nextInterval);
  //   } else {
  //     print("Erro ao receber dados de heartbeat");
  //     _scheduleNextHeartbeat(60); // Usando 60 segundos como fallback
  //   }
  // }

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

  void handleDeliveryCompleted() async {
    bool success = await API.notifyDeliveryCompleted();
    if (success) {
      setState(() {
        deliveryCompleted = true;
        hasAcceptedDelivery = false;
        hasPickedUp = false;
        deliveryData = null;
        statusMessage = 'Entrega concluída com sucesso!';
      });
      updateSaldo();
    } else {
      print("Falha ao confirmar a entrega.");
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
}
