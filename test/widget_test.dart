import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mescla_invest/main.dart';

void main() {
  testWidgets('Mostra a tela inicial e navega para InicioScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // SplashScreen navega após ~3s
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar Conta'), findsOneWidget);
  });
}
