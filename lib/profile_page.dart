import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? nomeUsuario;
  String? emailUsuario;
  String? codigoConvite;
  bool editando = false;
  bool carregando = false;
  String? mensagem;

  final TextEditingController _conviteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nomeUsuario = prefs.getString('userName') ?? 'Usuário';
      emailUsuario = prefs.getString('userEmail') ?? '';
      codigoConvite = prefs.getString('userInvite');
      if (codigoConvite != null) _conviteController.text = codigoConvite!;
    });
  }

  Future<void> _salvarConvite() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('idUser');

    if (userId == null) {
      setState(() => mensagem = "Usuário não encontrado.");
      return;
    }

    final code = _conviteController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 8) {
      setState(() => mensagem = "Código deve ter 8 letras maiúsculas.");
      return;
    }

    setState(() => carregando = true);
    try {
      final response = await API.setInviteCode(userId, code);
      if (response['success'] == true) {
        await prefs.setString('userInvite', code);
        setState(() {
          codigoConvite = code;
          editando = false;
          mensagem = "Código salvo com sucesso!";
        });
      } else {
        setState(() {
          mensagem = response['message'] ?? "Falha ao salvar código.";
        });
      }
    } catch (e) {
      setState(() => mensagem = "Erro ao comunicar com o servidor.");
    } finally {
      setState(() => carregando = false);
    }
  }

  Future<void> _gerarNovoCodigo() async {
    setState(() => carregando = true);
    try {
      final response = await API.generateRandomInviteCode();
      if (response['code'] != null) {
        _conviteController.text = response['code'];
        setState(() => mensagem = "Novo código gerado!");
      } else {
        setState(() => mensagem = "Falha ao gerar novo código.");
      }
    } catch (e) {
      setState(() => mensagem = "Erro ao gerar código.");
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Usuário'),
        centerTitle: true,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomeUsuario ?? '',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(emailUsuario ?? ''),
                  const Divider(height: 32),
                  const Text(
                    "Código de Convite",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _conviteController,
                    enabled: editando,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      suffixIcon: editando
                          ? IconButton(
                              icon: const Icon(Icons.save, color: Colors.green),
                              onPressed: _salvarConvite,
                            )
                          : IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                setState(() => editando = true);
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Gerar Novo"),
                        onPressed: _gerarNovoCodigo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text("Copiar"),
                        onPressed: () {
                          final code = _conviteController.text;
                          if (code.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Código copiado: $code')),
                            );
                            Clipboard.setData(ClipboardData(text: code));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  if (mensagem != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      mensagem!,
                      style: TextStyle(
                        color: mensagem!.contains("sucesso")
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ]
                ],
              ),
            ),
    );
  }
}
