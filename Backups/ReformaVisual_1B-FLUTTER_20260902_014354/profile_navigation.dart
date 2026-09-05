enum AppArea {
  comprar,
  fornecedor,
  entregador,
}

class ProfileNavigation {
  const ProfileNavigation._();

  static List<AppArea> areas({
    required bool isFornecedor,
    required bool isMotoboy,
  }) {
    return <AppArea>[
      AppArea.comprar,
      if (isFornecedor) AppArea.fornecedor,
      if (isMotoboy) AppArea.entregador,
    ];
  }
}
