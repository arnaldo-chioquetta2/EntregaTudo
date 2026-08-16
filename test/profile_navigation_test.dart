import 'package:flutter_test/flutter_test.dart';

import 'package:entregatudo/app/profile_navigation.dart';

void main() {
  test('usuario comum possui somente Comprar', () {
    expect(
      ProfileNavigation.areas(isFornecedor: false, isMotoboy: false),
      <AppArea>[AppArea.comprar],
    );
  });

  test('fornecedor possui Comprar e Fornecedor', () {
    expect(
      ProfileNavigation.areas(isFornecedor: true, isMotoboy: false),
      <AppArea>[AppArea.comprar, AppArea.fornecedor],
    );
  });

  test('entregador possui Comprar e Entregador', () {
    expect(
      ProfileNavigation.areas(isFornecedor: false, isMotoboy: true),
      <AppArea>[AppArea.comprar, AppArea.entregador],
    );
  });

  test('fornecedor e entregador mantem as duas areas', () {
    expect(
      ProfileNavigation.areas(isFornecedor: true, isMotoboy: true),
      <AppArea>[
        AppArea.comprar,
        AppArea.fornecedor,
        AppArea.entregador,
      ],
    );
  });
}
