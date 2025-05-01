import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:entregatudo/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResgatePage extends StatefulWidget {
  @override
  _ResgatePageState createState() => _ResgatePageState();
}

class _ResgatePageState extends State<ResgatePage> {
  String saldo = 'R\$ 0,00';
  String valorDebitado = 'R\$ 0,00';
  String valorResgate = 'R\$ 0,00';
  bool resgatePendente = false;
  String dataResgatePendente = '';
  String valorPendente = 'R\$ 0,00';
  String dataResgateFormatada = ''; // Formatted date string

  @override
  void initState() {
    super.initState();
    fetchSaldo();
  }

  void processResgate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('idUser');
    if (userId != null) {
      try {
        bool success = await API.sacar(userId);

        if (success) {
          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('Resgate Concluído'),
                  content: Text('Seu resgate foi processado com sucesso.'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: Text('Ok'),
                    )
                  ],
                );
              });
        } else {
          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('Erro'),
                  content: Text(
                      'Falha ao processar resgate. Tente novamente mais tarde.'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Ok'),
                    )
                  ],
                );
              });
        }
      } catch (e) {
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Erro'),
                content: Text('Ocorreu um erro durante a operação: $e'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Ok'),
                  )
                ],
              );
            });
      }
    }
  }

  void fetchSaldo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');
    if (userId == null) {
      print("UserID não encontrado. Faça login novamente.");
      return;
    }

    try {
      // ------ saldo ---------------------------------------------------------
      final raw = await API.saldo(userId); // sempre String
      final saldoNum =
          double.tryParse(raw.replaceAll(',', '.')) ?? 0.0; // "123,45" → 123.45

      // ------ débito --------------------------------------------------------
      final debito = saldoNum >= 500 ? 1.0 : 2.0;
      final valorAResgatar = saldoNum - debito;

      // ------ pendente ------------------------------------------------------
      final pendenteInt = prefs.getInt('Pendente') ?? 0; // agora lê como int
      valorPendente = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
          .format(pendenteInt.toDouble()); // R$ 0,00 ou outro

      // ------ data resgate --------------------------------------------------
      dataResgatePendente = prefs.getString('DtaPedResg') ?? '';
      if (dataResgatePendente.isNotEmpty) {
        final parsedDate = DateTime.parse(dataResgatePendente);
        dataResgateFormatada =
            DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
      }
      resgatePendente = pendenteInt > 0;

      // ------ exibir --------------------------------------------------------
      if (!mounted) return;
      setState(() {
        saldo = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
            .format(saldoNum);
        valorDebitado = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
            .format(debito);
        valorResgate = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
            .format(valorAResgatar);
      });
    } catch (e) {
      print('Erro ao buscar saldo: $e');
    }
  }

  // void fetchSaldo() async {
  //   print('fetchSaldo');
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   int? userId = prefs.getInt('idUser');
  //   if (userId != null) {
  //     try {
  //       String newSaldo = await API.saldo(userId);
  //       double saldoNum = double.parse(newSaldo);
  //       double debito = saldoNum >= 500 ? 1.0 : 2.0;
  //       double valorAResgatar = saldoNum - debito;
  //       valorPendente = prefs.getString('Pendente') ?? 'R\$ 0,00';
  //       dataResgatePendente = prefs.getString('DtaPedResg') ?? '';
  //       if (dataResgatePendente.isNotEmpty) {
  //         DateTime parsedDate = DateTime.parse(dataResgatePendente);
  //         dataResgateFormatada =
  //             DateFormat('dd/MM/yyyy HH:mm').format(parsedDate); // Format date
  //       }
  //       resgatePendente = valorPendente != 'R\$ 0,00';
  //       setState(() {
  //         saldo = 'R\$ ${saldoNum.toStringAsFixed(2)}';
  //         valorDebitado = 'R\$ ${debito.toStringAsFixed(2)}';
  //         valorResgate = 'R\$ ${valorAResgatar.toStringAsFixed(2)}';
  //       });
  //     } catch (e) {
  //       print('Erro ao buscar saldo: $e');
  //     }
  //   } else {
  //     print("UserID não encontrado. Por favor, faça login novamente.");
  //   }
  // }

  void confirmResgate() {
    if (!resgatePendente) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Confirmar Resgate"),
            content:
                Text("Confirma transferência de $valorResgate para sua conta?"),
            actions: <Widget>[
              TextButton(
                child: Text("Cancelar"),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: Text("Confirmar"),
                onPressed: () {
                  Navigator.of(context).pop();
                  processResgate();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Resgate"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Saldo Total: $saldo", style: TextStyle(fontSize: 18)),
            Text("Custos Operacionais: $valorDebitado",
                style: TextStyle(fontSize: 18, color: Colors.red)),
            Text("Valor a Resgatar: $valorResgate",
                style: TextStyle(fontSize: 18, color: Colors.green)),
            if (resgatePendente) ...[
              Text("Resgate Pendente: $valorPendente",
                  style: TextStyle(fontSize: 18, color: Colors.orange)),
              Text("Data do Pedido: $dataResgateFormatada",
                  style: TextStyle(fontSize: 18, color: Colors.orange)),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: resgatePendente ? null : confirmResgate,
              child: Text(resgatePendente ? 'Resgate Pendente' : 'Resgatar'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(150, 40),
                backgroundColor: resgatePendente ? Colors.grey : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
