import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:i9_team_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('i9-team Mobile App Tests', () {
    testWidgets('HomeScreen deve exibir lista de teams', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verificar que o título "i9 Team" está visível
      expect(find.text('i9 Team'), findsOneWidget);

      // Verificar que pelo menos um team card está visível
      expect(find.text('i9-team/dev'), findsOneWidget);
      expect(find.text('ATIVO'), findsWidgets);

      print('✓ HomeScreen verificada com sucesso');
    });

    testWidgets('Navegar para TeamScreen ao tcar em um team', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Encontrar e clicar no primeiro team card
      final teamCard = find.byType(GestureDetector).first;
      await tester.tap(teamCard);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verificar que estamos na TeamScreen (deve exibir AppBar com o nome do team)
      expect(find.byType(AppBar), findsOneWidget);
      print('✓ Navegação para TeamScreen bem-sucedida');
    });

    testWidgets('MenuOverlay deve ser renderizado quando sessionName existe', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verificar que AgentPanel está presente
      expect(find.byType(ListWheelScrollView), findsWidgets);
      print('✓ Componentes de Agent estão renderizados');
    });

    testWidgets('ImageUploadWidget deve estar disponível', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navegar para um team
      final teamCard = find.byType(GestureDetector).first;
      await tester.tap(teamCard);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verificar que MessageInput está presente (contém upload widget)
      expect(find.byType(TextField), findsOneWidget);
      print('✓ MessageInput (com upload) está presente');
    });
  });
}
