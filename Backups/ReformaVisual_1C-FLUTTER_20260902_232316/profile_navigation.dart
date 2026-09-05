enum AppArea {
  comprar,
  entregador,
  fornecedor,
  captador,
}

class ProfileNavigation {
  const ProfileNavigation._();

  static List<AppArea> areas({
    required bool isFornecedor,
    required bool isMotoboy,
  }) {
    return <AppArea>[
      AppArea.comprar,
      if (isMotoboy) AppArea.entregador,
      if (isFornecedor) AppArea.fornecedor,
      AppArea.captador,
    ];
  }

  static AppArea selectedOrFirst({
    required List<AppArea> areas,
    AppArea? selected,
  }) {
    if (selected != null && areas.contains(selected)) return selected;
    return areas.first;
  }
}
