import 'dart:async';
import 'resgate_page.dart';
import 'settingsPage.dart';
import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'features/location_service.dart';
import 'package:entregatudo/models/delivery_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _locationService.requestPermissions();
    _scheduleNextHeartbeat(2);
    updateSaldo();
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Ação ao pressionar o botão (navegar para a tela de configurações)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
              child: const Text('Configurações'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(150, 40),
                backgroundColor: Colors.blue, // Cor azul para o botão
                foregroundColor: Colors.white, // Cor do texto (branco)
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Bordas arredondadas
                ),
              ),
            ),
            if (deliveryData != null) _buildDeliveryDetails(),
            if (deliveryData == null &&
                (deliveryCompleted || !hasAcceptedDelivery)) ...[
              Padding(
                padding: EdgeInsets.all(20),
                child: Text("Saldo $saldo",
                    style: TextStyle(fontSize: 18, color: Colors.black)),
              ),
              ElevatedButton(
                onPressed: null,
                child: const Text('Detalhes'),
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 40), backgroundColor: Colors.grey),
              ),
              SizedBox(height: 10),
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
                  minimumSize: Size(150, 40),
                  backgroundColor: Colors.grey,
                ),
              ),
            ],
            if (statusMessage != null)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(statusMessage!,
                    style: TextStyle(fontSize: 18, color: Colors.red)),
              ),
            if (hasAcceptedDelivery && !hasPickedUp)
              ElevatedButton(
                onPressed: () {
                  handlePickedUp();
                },
                child: const Text('Cheguei no Fornecedor'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(150, 40),
                  backgroundColor: Colors.orange,
                ),
              ),
            if (hasPickedUp && !deliveryCompleted)
              ElevatedButton(
                onPressed: () {
                  handleDeliveryCompleted();
                },
                child: const Text('Entrega Concluída'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(150, 40),
                  backgroundColor: Colors.green,
                ),
              ),
          ],
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
    DeliveryDetails? deliveryDetails = await API.sendHeartbeat();
    if (deliveryDetails != null) {
      double valorDelivery = deliveryDetails.valor ?? 0.0;
      int? currentChamado = prefs.getInt('currentChamado');
      if (deliveryDetails.chamado != currentChamado && valorDelivery > 0.0) {
        await prefs.setInt('currentChamado', deliveryDetails.chamado ?? 0);
        setState(() {
          deliveryData = {
            'enderIN': deliveryDetails.enderIN ?? 'Desconhecido',
            'enderFN': deliveryDetails.enderFN ?? 'Desconhecido',
            'dist': deliveryDetails.dist ?? 0.0,
            'valor': valorDelivery,
            'peso': deliveryDetails.peso ?? 'Não Informado',
            'chamado': deliveryDetails.chamado,
          };
        });
        int? userId = prefs.getInt('idUser');
        if (userId != null) {
          await API.reportViewToServer(userId, deliveryDetails.chamado);
          print(
              "Visualização reportada: chamado = ${deliveryDetails.chamado}, userId = $userId");
        }
      }
      int nextInterval = (deliveryDetails.modo ?? 3) == 3 ? 60 : 10;
      _scheduleNextHeartbeat(nextInterval);
    } else {
      print("Erro ao receber dados de heartbeat");
      _scheduleNextHeartbeat(60); // Usando 60 segundos como fallback
    }
  }

  void handleDeliveryResponse(bool accept) {
    if (accept) {
      setState(() {
        hasAcceptedDelivery = true;
        hasPickedUp = false;
        statusMessage = "Entrega aceita. A caminho do fornecedor.";
        deliveryData = null;
      });
    } else {
      setState(() {
        hasAcceptedDelivery = false;
        hasPickedUp = false;
        deliveryCompleted = true;
        statusMessage = "Entrega recusada.";
        deliveryData = null;
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
    print("updateSaldo");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('idUser');
    if (userId != null) {
      try {
        String newSaldo = await API.saldo(userId);
        print("Saldo = " + newSaldo);
        setState(() {
          saldo = 'R\$ $newSaldo';
          saldoNum =
              double.parse(newSaldo.replaceAll('R\$', '').replaceAll(',', '.'));
        });
      } catch (e) {
        print('Erro ao atualizar saldo: $e');
      }
    }
  }
}
