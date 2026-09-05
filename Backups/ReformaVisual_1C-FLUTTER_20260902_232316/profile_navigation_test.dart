import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/app/profile_navigation.dart';

void main() {
  test('usuario comum possui Compra e Captador', () {
    expect(
      ProfileNavigation.areas(isFornecedor: false, isMotoboy: false),
      <AppArea>[AppArea.comprar, AppArea.captador],
    );
  });

  test('fornecedor possui Compra, Fornecedor e Captador', () {
    expect(
      ProfileNavigation.areas(isFornecedor: true, isMotoboy: false),
      <AppArea>[AppArea.comprar, AppArea.fornecedor, AppArea.captador],
    );
  });

  test('entregador possui Compra, Entregador e Captador', () {
    expect(
      ProfileNavigation.areas(isFornecedor: false, isMotoboy: true),
      <AppArea>[AppArea.comprar, AppArea.entregador, AppArea.captador],
    );
  });

  test('fornecedor e entregador mantem as duas areas independentes', () {
    expect(
      ProfileNavigation.areas(isFornecedor: true, isMotoboy: true),
      <AppArea>[
        AppArea.comprar,
        AppArea.entregador,
        AppArea.fornecedor,
        AppArea.captador,
      ],
    );
  });

  test('areas nao possuem duplicatas e mantem compra e captador unicos', () {
    for (final combination in [
      (isFornecedor: false, isMotoboy: false),
      (isFornecedor: false, isMotoboy: true),
      (isFornecedor: true, isMotoboy: false),
      (isFornecedor: true, isMotoboy: true),
    ]) {
      final areas = ProfileNavigation.areas(
        isFornecedor: combination.isFornecedor,
        isMotoboy: combination.isMotoboy,
      );
      expect(areas.toSet().length, areas.length);
      expect(areas.where((area) => area == AppArea.comprar).length, 1);
      expect(areas.where((area) => area == AppArea.captador).length, 1);
    }
  });

  test('selecionada removida retorna a primeira area valida', () {
    const areas = <AppArea>[
      AppArea.comprar,
      AppArea.entregador,
      AppArea.captador,
    ];

    expect(
      ProfileNavigation.selectedOrFirst(
        areas: areas,
        selected: AppArea.fornecedor,
      ),
      AppArea.comprar,
    );
    expect(
      ProfileNavigation.selectedOrFirst(
        areas: areas,
        selected: AppArea.entregador,
      ),
      AppArea.entregador,
    );
  });
}
