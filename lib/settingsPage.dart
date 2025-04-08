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

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      // Aplica a formatação aos valores
      String minValue = _minValueController.text.isNotEmpty
          ? _formatValue(
              double.parse(_minValueController.text.replaceAll(',', '.')))
          : '';
      String kmRate = _formatValue(
          double.parse(_kmRateController.text.replaceAll(',', '.')));
      String rainSurcharge = _rainSurchargeController.text.isNotEmpty
          ? _formatValue(
              double.parse(_rainSurchargeController.text.replaceAll(',', '.')))
          : '';
      String nightSurcharge = _nightSurchargeController.text.isNotEmpty
          ? _formatValue(
              double.parse(_nightSurchargeController.text.replaceAll(',', '.')))
          : '';
      String dawnSurcharge = _dawnSurchargeController.text.isNotEmpty
          ? _formatValue(
              double.parse(_dawnSurchargeController.text.replaceAll(',', '.')))
          : '';
      String weightSurcharge = _weightSurchargeController.text.isNotEmpty
          ? _formatValue(double.parse(
              _weightSurchargeController.text.replaceAll(',', '.')))
          : '';
      String customDeliverySurcharge =
          _customDeliverySurchargeController.text.isNotEmpty
              ? _formatValue(double.parse(
                  _customDeliverySurchargeController.text.replaceAll(',', '.')))
              : '';

      // Exibe a mensagem de confirmação
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmar Envio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Valor Mínimo: $minValue'),
              Text('Valor por Km Rodado: $kmRate'),
              Text('Adicional por Chuva: $rainSurcharge'),
              Text('Adicional Noturno: $nightSurcharge'),
              Text('Adicional Madrugada: $dawnSurcharge'),
              Text('Adicional por Peso Maior: $weightSurcharge'),
              Text(
                  'Adicional por Entrega Personalizada: $customDeliverySurcharge'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Fecha o diálogo
              },
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                // Aqui você pode adicionar a lógica de envio
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Configurações enviadas com sucesso!')),
                );
                Navigator.pop(context); // Fecha o diálogo
              },
              child: Text('Enviar'),
            ),
          ],
        ),
      );
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
