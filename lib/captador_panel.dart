import 'package:flutter/material.dart';
import 'package:entregatudo/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaptadorPanelPage extends StatefulWidget {
  const CaptadorPanelPage({super.key});

  @override
  State<CaptadorPanelPage> createState() => _CaptadorPanelPageState();
}

class _CaptadorPanelPageState extends State<CaptadorPanelPage> {
  final TextEditingController _codeController = TextEditingController();
  String? _statusMessage;
  Color _statusColor = Colors.black;
  bool _isLoading = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('idUser');
    });
  }

  Future<void> _generateCode() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Gerando código...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.generateInviteCode();
      final code = result['code'] ?? 'ERRO';
      _codeController.text = code;

      setState(() {
        _statusMessage = "Código gerado com sucesso: $code";
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao gerar código.";
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAvailability() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _userId == null) {
      setState(() {
        _statusMessage = "Informe um código e verifique se está disponível.";
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Verificando disponibilidade...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.checkInviteAvailability(code, _userId!);
      final available = result['available'] == true;

      setState(() {
        _statusMessage = available
            ? "Código disponível para uso!"
            : "Código já está em uso.";
        _statusColor = available ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao verificar código.";
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _userId == null) {
      setState(() {
        _statusMessage = "Preencha um código antes de salvar.";
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Salvando código...";
      _statusColor = Colors.black;
    });

    try {
      final result = await API.setInvite(code, _userId!);
      final success = result['success'] == true;

      setState(() {
        _statusMessage = success
            ? "Código salvo com sucesso!"
            : result['message'] ?? "Erro ao salvar código.";
        _statusColor = success ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao salvar código.";
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Captador'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Gerar ou configurar código de convite",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: "Código do convite (8 letras maiúsculas)",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _generateCode,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Gerar código aleatório"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _checkAvailability,
                    icon: const Icon(Icons.search),
                    label: const Text("Verificar disponibilidade"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _saveCode,
                    icon: const Icon(Icons.save),
                    label: const Text("Salvar código"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
