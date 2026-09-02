import 'package:entregatudo/api.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isStepTwo = false;

  String get _userIdentifier => _userController.text.trim();

  @override
  void dispose() {
    _userController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar senha'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _userController,
              enabled: !_isLoading && !_isStepTwo,
              decoration: const InputDecoration(
                labelText: 'UsuÃ¡rio, e-mail ou telefone',
              ),
            ),
            const SizedBox(height: 16),
            if (!_isStepTwo) _buildSendCodeButton(),
            if (_isStepTwo) ...[
              const Text(
                'Digite o cÃ³digo recebido e escolha uma nova senha.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                'Identificador: $_userIdentifier',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'CÃ³digo',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova senha',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha',
                ),
              ),
              const SizedBox(height: 16),
              _buildResetPasswordButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSendCodeButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleForgotPassword,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Enviar cÃ³digo'),
    );
  }

  Widget _buildResetPasswordButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleResetPassword,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Alterar senha'),
    );
  }

  Future<void> _handleForgotPassword() async {
    final user = _userIdentifier;
    if (user.isEmpty) {
      _showAlert(
        title: 'Erro',
        message: 'Informe seu usuÃ¡rio, e-mail ou telefone.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await API.forgotPassword(user);
      final bool success = result['Erro'] == 0;
      final String message =
          'Se os dados estiverem corretos, enviaremos instruÃ§Ãµes para redefinir sua senha.';

      if (success && mounted) {
        setState(() => _isStepTwo = true);
      }

      if (!mounted) {
        return;
      }

      if (success) {
        await _showAlert(
          title: 'RecuperaÃ§Ã£o de senha',
          message: message,
        );
      } else {
        await _showAlert(
          title: 'Erro',
          message: _extractMessage(result),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    final user = _userIdentifier;
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.isEmpty) {
      _showAlert(
        title: 'Erro',
        message: 'Informe o cÃ³digo recebido.',
      );
      return;
    }

    if (newPassword.length < 6) {
      _showAlert(
        title: 'Erro',
        message: 'A nova senha deve ter no mÃ­nimo 6 caracteres.',
      );
      return;
    }

    if (confirmPassword != newPassword) {
      _showAlert(
        title: 'Erro',
        message: 'A confirmaÃ§Ã£o da senha deve ser igual Ã  nova senha.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await API.resetPassword(
        user: user,
        code: code,
        newPassword: newPassword,
      );

      if (!mounted) {
        return;
      }

      if (result['Erro'] == 0) {
        await _showAlert(
          title: 'Sucesso',
          message: 'Senha alterada com sucesso.',
        );

        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      await _showAlert(
        title: 'Erro',
        message: _extractMessage(result),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _extractMessage(Map<String, dynamic> result) {
    final dynamic message = result['msg'] ?? result['DescErro'] ?? result['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    return 'NÃ£o foi possÃ­vel processar a solicitaÃ§Ã£o. Tente novamente.';
  }

  Future<void> _showAlert({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
