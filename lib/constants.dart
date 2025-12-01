class AppConfig {
  static const String versaoApp = '1.4.4';

  static int get versaoAppInt {
    final p = versaoApp.split('.');
    final major = int.parse(p[0]);
    final minor = int.parse(p[1]);
    final patch = int.parse(p[2]);
    return major * 100 + minor * 10 + patch;
  }
}

// VERSÃO NÃO ENVIADA AO SERVIDOR
// 1.4.4 MotoBoy e Fornecedor ao mesmo tempo

// VERSÃO JÁ ENVIADA AO SERVIDOR
// 1.4.3 Mais logs no cadastro
// 1.4.3 Modo offline para MotoBoy e Fornecedor
// 1.4.2 Mostra melhor formatado a mensagem de usuário já existente no cadastro
// 1.4.1 Prevenção para o erro de autenticação na gravação das configurações
// 1.4.1 Recusa por versão antiga
// 1.4.0 Correção estavam sendo mostradas vendas falsas
// 1.3.9 Fornecedor recebe aviso pelo App sobre a venda
// 1.3.8 Correção da crítica da placa
// 1.3.7 Correção do cadastro
// 1.3.6 Log na conferência do convite
// 1.3.5 Log para o servidor ao logar e ao cadastrar
