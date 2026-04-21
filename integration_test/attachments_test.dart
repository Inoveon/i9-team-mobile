// Smoke test estrutural para o MessageInput com anexos (Onda 5).
//
// Não dispara image_picker real (requer device picker nativo); apenas valida
// que o botão 📎 está presente e que abrir o bottom sheet mostra as opções
// esperadas.
//
// Execute com:
//   flutter test integration_test/attachments_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:i9_team_mobile/features/team/widgets/message_input.dart';
import 'package:i9_team_mobile/features/upload/services/image_upload_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MessageInput — Onda 5 anexos', () {
    testWidgets('exibe botão 📎 de anexar imagem', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MessageInput(
                teamId: 'test-team',
                onSend: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('bottom sheet abre com opções Câmera e Galeria', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MessageInput(
                teamId: 'test-team',
                onSend: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap no botão anexar
      await tester.tap(find.byIcon(Icons.attach_file_rounded));
      await tester.pumpAndSettle();

      // Deve mostrar as duas opções obrigatórias
      expect(find.text('Câmera'), findsOneWidget);
      expect(find.text('Galeria'), findsOneWidget);
    });
  });

  group('ImageUploadService — validação client', () {
    test('kMaxFileBytes == 5MB', () {
      expect(kMaxFileBytes, 5 * 1024 * 1024);
    });

    test('kMaxAttachmentsPerMessage == 6', () {
      expect(kMaxAttachmentsPerMessage, 6);
    });

    test('kAllowedMimes cobre png/jpeg/gif/webp', () {
      expect(kAllowedMimes.contains('image/png'), isTrue);
      expect(kAllowedMimes.contains('image/jpeg'), isTrue);
      expect(kAllowedMimes.contains('image/gif'), isTrue);
      expect(kAllowedMimes.contains('image/webp'), isTrue);
      expect(kAllowedMimes.contains('image/bmp'), isFalse);
      expect(kAllowedMimes.contains('image/heic'), isFalse);
    });
  });
}
