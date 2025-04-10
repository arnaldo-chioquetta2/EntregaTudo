import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Controladores para os campos de texto
  final TextEditingController _minValueController = TextEditingController();
  final TextEditingController _kmRateController = TextEditingController();
  final TextEditingController _rainSurchargeController =
      TextEditingController();
  final TextEditingController _nightSurchargeController =
      TextEditingController();
  final TextEditingController _dawnSurchargeController =
      TextEditingController();
  final TextEditingController _weightSurchargeController =
      TextEditingController();
  final TextEditingController _customDeliverySurchargeController =
      TextEditingController();

  // Chave global do formulário
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _vazio = 0;

  // Função para validar os campos
  String? _validateInput(String? value, {bool isRequired = false}) {
    if (isRequired && (value == null || value.isEmpty)) {
      return 'Campo obrigatório';
    }
    if (value != null && value.isNotEmpty) {
      // Verifica se o valor contém apenas números, pontos ou vírgulas
      final regex = RegExp(r'^[0-9.,]+$');
      if (!regex.hasMatch(value)) {
        return 'Apenas números, pontos ou vírgulas são permitidos';
      }
    }
    return null; // Sem erros
  }

  // Função para formatar o valor (ex.: "1,00")
  String _formatValue(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      // Converte os valores dos controladores para double
      double minValue = _minValueController.text.isNotEmpty
          ? double.parse(_minValueController.text.replaceAll(',', '.'))
          : 0.0;
      double kmRate = double.parse(_kmRateController.text.replaceAll(',', '.'));
      double rainSurcharge = _rainSurchargeController.text.isNotEmpty
          ? double.parse(_rainSurchargeController.text.replaceAll(',', '.'))
          : 0.0;
      double nightSurcharge = _nightSurchargeController.text.isNotEmpty
          ? double.parse(_nightSurchargeController.text.replaceAll(',', '.'))
          : 0.0;
      double dawnSurcharge = _dawnSurchargeController.text.isNotEmpty
          ? double.parse(_dawnSurchargeController.text.replaceAll(',', '.'))
          : 0.0;
      double weightSurcharge = _weightSurchargeController.text.isNotEmpty
          ? double.parse(_weightSurchargeController.text.replaceAll(',', '.'))
          : 0.0;
      double customDeliverySurcharge =
          _customDeliverySurchargeController.text.isNotEmpty
              ? double.parse(
                  _customDeliverySurchargeController.text.replaceAll(',', '.'))
              : 0.0;

      // Chama o método para salvar as configurações na API
      final result = null;
      // final result = await API.saveConfigurations(
      //   minValue,
      //   kmRate,
      //   rainSurcharge,
      //   nightSurcharge,
      //   dawnSurcharge,
      //   weightSurcharge,
      //   customDeliverySurcharge,
      // );

      // Exibe a mensagem de confirmação
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Erro'),
            content: Text(result['message']),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Fecha o diálogo
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      // Se houver erros, exibe uma mensagem
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Por favor, revise os valores nos campos em vermelho.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final result = await API.obtemCfgValores(-23.5505, -46.6333);
      setState(() {
        _vazio = result['vazio'];
        _minValueController.text =
            result['minValue'] == 0 ? '' : _formatValue(result['minValue']);
        _kmRateController.text =
            result['kmRate'] == 0 ? '' : _formatValue(result['kmRate']);
        _rainSurchargeController.text = result['rainSurcharge'] == 0
            ? ''
            : _formatValue(result['rainSurcharge']);
        _nightSurchargeController.text = result['nightSurcharge'] == 0
            ? ''
            : _formatValue(result['nightSurcharge']);
        _dawnSurchargeController.text = result['dawnSurcharge'] == 0
            ? ''
            : _formatValue(result['dawnSurcharge']);
        _weightSurchargeController.text = result['weightSurcharge'] == 0
            ? ''
            : _formatValue(result['weightSurcharge']);
        _customDeliverySurchargeController.text =
            result['customDeliverySurcharge'] == 0
                ? ''
                : _formatValue(result['customDeliverySurcharge']);
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Configurações"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_vazio == 1)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.8), // Fundo amarelo
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orange, width: 2), // Borda laranja
                  ),
                  child: Text(
                    'Estes são valores médios utilizados na sua região. Voce pode alterar como quiser.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Texto preto
                    ),
                  ),
                ),
              if (_vazio == 0)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8), // Fundo azul
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.blueAccent, width: 2), // Borda azul
                  ),
                  child: Text(
                    'Você pode alterar os preços conforme sua necessidade.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Texto branco
                    ),
                  ),
                ),

              SizedBox(height: 16),
              // Valor Mínimo
              TextFormField(
                controller: _minValueController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Valor Mínimo",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateInput(value), // Não obrigatório
              ),
              SizedBox(height: 16),

              // Valor por Km Rodado
              TextFormField(
                controller: _kmRateController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Valor por Km Rodado",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    _validateInput(value, isRequired: true), // Obrigatório
              ),
              SizedBox(height: 16),

              // Adicional por Chuva
              TextFormField(
                controller: _rainSurchargeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Adicional por Chuva",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateInput(value), // Não obrigatório
              ),
              SizedBox(height: 16),

              // Adicional Noturno
              TextFormField(
                controller: _nightSurchargeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Adicional Noturno",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateInput(value), // Não obrigatório
              ),
              SizedBox(height: 16),

              // Adicional Madrugada
              TextFormField(
                controller: _dawnSurchargeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Adicional Madrugada",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateInput(value), // Não obrigatório
              ),
              SizedBox(height: 16),

              // Adicional por Peso Maior
              TextFormField(
                controller: _weightSurchargeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Adicional por Peso Maior",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateInput(value), // Não obrigatório
              ),
              SizedBox(height: 16),

              // Adicional por Entrega Personalizada
              TextFormField(
                controller: _customDeliverySurchargeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Adicional por Entrega Personalizada",
                  helperText: "Exemplo: Subir escada",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateInput(value), // Não obrigatório
              ),
              SizedBox(height: 32),

              // Botão para Salvar
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text("Salvar Configurações"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Limpar os controladores ao sair da tela
    _minValueController.dispose();
    _kmRateController.dispose();
    _rainSurchargeController.dispose();
    _nightSurchargeController.dispose();
    _dawnSurchargeController.dispose();
    _weightSurchargeController.dispose();
    _customDeliverySurchargeController.dispose();
    super.dispose();
  }
}
