class AppConfig {
  static const String versaoApp = '1.4.0';

  // Converte "1.4.0" → 140
  static int get versaoAppInt {
    final p = versaoApp.split('.');
    final major = int.parse(p[0]);
    final minor = int.parse(p[1]);
    final patch = int.parse(p[2]);
    return major * 100 + minor * 10 + patch;
  }
}

//// 1.4.1 Prevenção para o erro de autenticação na gravação das configurações
//// 1.4.1 Recusa por versão antiga
// 1.4.0 Correção estavam sendo mostradas vendas falsas
// 1.3.9 Fornecedor recebe aviso pelo App sobre a venda
// 1.3.8 Correção da crítica da placa
// 1.3.7 Correção do cadastro
// 1.3.6 Log na conferência do convite
// 1.3.5 Log para o servidor ao logar e ao cadastrar
// 1.3.4 Confirmação de código na entrega
// 1.3.3 Convite na fluxo certo de crítica
// 1.3.2 Fornecedor
// 1.3.1 Mostras as lojas on-line
// 1.3.0 Salvar senha e olhar a senha
// 1.2.9 Convite
