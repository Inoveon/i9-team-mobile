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

import 'package:i9_team_mobile/features/team/providers/optimistic_messages_provider.dart';
import 'package:i9_team_mobile/features/team/widgets/message_input.dart';
import 'package:i9_team_mobile/features/team/widgets/user_bubble.dart';
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

  group('OptimisticMessagesNotifier', () {
    test('add retorna id e insere na lista', () {
      final notifier = OptimisticMessagesNotifier();
      final id = notifier.add(text: 'ping', attachments: const []);
      expect(id, startsWith('opt_'));
      expect(notifier.state.length, 1);
      expect(notifier.state.first.text, 'ping');
    });

    test('clearIfMatches remove por prefixo de texto', () {
      final notifier = OptimisticMessagesNotifier();
      notifier.add(text: 'deploy v42', attachments: const []);
      notifier.clearIfMatches('deploy v42');
      expect(notifier.state, isEmpty);
    });

    test('clearIfMatches por containsPartial (eco com @path)', () {
      final notifier = OptimisticMessagesNotifier();
      notifier.add(text: 'olha essa tela', attachments: const []);
      // eco do backend: "olha essa tela\n\n@/uploads/teamA/uuid.png"
      notifier.clearIfMatches('olha essa tela\n\n@/uploads/teamA/uuid.png');
      expect(notifier.state, isEmpty);
    });

    test('markRejected flag attachment sem remover a msg', () {
      final notifier = OptimisticMessagesNotifier();
      final id = notifier.add(
        text: '',
        attachments: const [
          BubbleAttachment(remoteUrl: '/uploads/t/abc123.png', filename: 'a'),
          BubbleAttachment(remoteUrl: '/uploads/t/def456.png', filename: 'b'),
        ],
      );
      notifier.markRejected(id, {'abc123'});
      final msg = notifier.state.single;
      expect(msg.attachments[0].failed, isTrue);
      expect(msg.attachments[1].failed, isFalse);
    });

    test('clearAll zera tudo e cancela timers', () {
      final notifier = OptimisticMessagesNotifier();
      notifier.add(text: '1', attachments: const []);
      notifier.add(text: '2', attachments: const []);
      expect(notifier.state.length, 2);
      notifier.clearAll();
      expect(notifier.state, isEmpty);
    });
  });

  group('UserBubble — render com anexos', () {
    testWidgets('renderiza bolha com 2 thumbs e texto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserBubble(
              text: 'teste',
              attachments: [
                BubbleAttachment(remoteUrl: '/uploads/a.png'),
                BubbleAttachment(remoteUrl: '/uploads/b.png'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('teste'), findsOneWidget);
      // 2 Image.network (fallback remoto)
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('pending=true mostra spinner "enviando..."', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserBubble(text: 'wait', pending: true),
          ),
        ),
      );
      expect(find.text('enviando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
