import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Controladores
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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _vazio = 0;
  bool _isSaved = false;

  String? _validateInput(String? value, {bool isRequired = false}) {
    if (isRequired && (value == null || value.isEmpty)) {
      return 'Campo obrigatório';
    }
    if (value != null && value.isNotEmpty) {
      final regex = RegExp(r'^[0-9.,]+$');
      if (!regex.hasMatch(value)) {
        return 'Apenas números, pontos ou vírgulas são permitidos';
      }
    }
    return null;
  }

  String _formatValue(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
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

      final result = await API.saveConfigurations(
        minValue,
        kmRate,
        rainSurcharge,
        nightSurcharge,
        dawnSurcharge,
        weightSurcharge,
        customDeliverySurcharge,
      );

      if (result['success']) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result['message'])));
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erro'),
            content: Text(result['message']),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
      print('Erro ao carregar configurações: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configurações")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() => _isSaved = false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_vazio == 1)
                _buildAviso(
                    "Estes são valores médios utilizados na sua região.",
                    Colors.yellow,
                    Colors.orange,
                    Colors.black)
              else
                _buildAviso(
                    "Você pode alterar os preços conforme sua necessidade.",
                    Colors.blue,
                    Colors.blueAccent,
                    Colors.white),
              const SizedBox(height: 16),
              _buildCampo("Valor Mínimo", _minValueController),
              const SizedBox(height: 16),
              _buildCampo("Valor por Km Rodado", _kmRateController,
                  obrigatorio: true),
              const SizedBox(height: 16),
              _buildCampo("Adicional por Chuva", _rainSurchargeController),
              const SizedBox(height: 16),
              _buildCampo("Adicional Noturno", _nightSurchargeController),
              const SizedBox(height: 16),
              _buildCampo("Adicional Madrugada", _dawnSurchargeController),
              const SizedBox(height: 16),
              _buildCampo(
                  "Adicional por Peso Maior", _weightSurchargeController),
              const SizedBox(height: 16),
              _buildCampo("Adicional por Entrega Personalizada",
                  _customDeliverySurchargeController,
                  helper: "Exemplo: Subir escada"),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_isSaved) {
                    Navigator.pop(context);
                  } else {
                    _saveSettings();
                  }
                },
                child: Text(_isSaved ? "OK" : "Salvar Configurações"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              // const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAviso(String texto, Color bg, Color border, Color txt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 2),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: txt),
      ),
    );
  }

  Widget _buildCampo(String label, TextEditingController controller,
      {bool obrigatorio = false, String? helper}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => _validateInput(value, isRequired: obrigatorio),
    );
  }

  @override
  void dispose() {
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
