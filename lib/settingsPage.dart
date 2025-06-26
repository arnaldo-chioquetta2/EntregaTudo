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
  final TextEditingController _rainSurchargeController = TextEditingController();
  final TextEditingController _nightSurchargeController = TextEditingController();
  final TextEditingController _dawnSurchargeController = TextEditingController();
  final TextEditingController _weightSurchargeController = TextEditingController();
  final TextEditingController _customDeliverySurchargeController = TextEditingController();

  // Chave global do formulário
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Variável para armazenar o valor que vem da API
  int _vazio = 0;

  // Variável para controlar o estado do botão
  bool _isSaved = false;

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

  // Função para salvar as configurações
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
      final result = await API.saveConfigurations(
        minValue,
        kmRate,
        rainSurcharge,
        nightSurcharge,
        dawnSurcharge,
        weightSurcharge,
        customDeliverySurcharge,
      );

      // Exibe a mensagem de confirmação
      if (result['success']) {
        setState(() {
          _isSaved = true;
        });
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
    print('Iniciando _loadSettings...'); // Log para verificar se a função está sendo chamada
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      print('Chamando API.obtemCfgValores...'); // Log para verificar se a API está sendo chamada
      final result = await API.obtemCfgValores(-23.5505, -46.6333);
      print('Resultado da API: $result'); // Log para verificar o resultado da API

      setState(() {
        _vazio = result['vazio'];
        print('Valor de _vazio: $_vazio'); // Log para verificar o valor de _vazio

        _minValueController.text = result['minValue'] == 0 ? '' : _formatValue(result['minValue']);
        _kmRateController.text = result['kmRate'] == 0 ? '' : _formatValue(result['kmRate']);
        _rainSurchargeController.text = result['rainSurcharge'] == 0 ? '' : _formatValue(result['rainSurcharge']);
        _nightSurchargeController.text = result['nightSurcharge'] == 0 ? '' : _formatValue(result['nightSurcharge']);
        _dawnSurchargeController.text = result['dawnSurcharge'] == 0 ? '' : _formatValue(result['dawnSurcharge']);
        _weightSurchargeController.text = result['weightSurcharge'] == 0 ? '' : _formatValue(result['weightSurcharge']);
        _customDeliverySurchargeController.text = result['customDeliverySurcharge'] == 0 ? '' : _formatValue(result['customDeliverySurcharge']);

        print('Valor de _minValueController: ${_minValueController.text}'); // Log para verificar o valor de _minValueController
        print('Valor de _kmRateController: ${_kmRateController.text}'); // Log para verificar o valor de _kmRateController
        print('Valor de _rainSurchargeController: ${_rainSurchargeController.text}'); // Log para verificar o valor de _rainSurchargeController
        print('Valor de _nightSurchargeController: ${_nightSurchargeController.text}'); // Log para verificar o valor de _nightSurchargeController
        print('Valor de _dawnSurchargeController: ${_dawnSurchargeController.text}'); // Log para verificar o valor de _dawnSurchargeController
        print('Valor de _weightSurchargeController: ${_weightSurchargeController.text}'); // Log para verificar o valor de _weightSurchargeController
        print('Valor de _customDeliverySurchargeController: ${_customDeliverySurchargeController.text}'); // Log para verificar o valor de _customDeliverySurchargeController
      });
    } catch (e) {
      print('Erro ao carregar configurações: $e'); // Log para verificar qualquer erro que ocorra
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
          onChanged: () {
            setState(() {
              _isSaved = false;
            });
          },
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
                    'Estes são valores médios utilizados na sua região. Você pode alterar como quiser.',
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
                validator: (value) => _validateInput(value, isRequired: true), // Obrigatório
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
                onPressed: () {
                  if (_isSaved) {
                    Navigator.pop(context); // Redireciona para a página principal
                  } else {
                    _saveSettings();
                  }
                },
                child: Text(_isSaved ? "OK" : "Salvar Configurações"),
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

