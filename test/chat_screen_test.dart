import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/features/chat/screens/chat_screen.dart';
import 'package:fitness_app/features/chat/widgets/chat_message_bubble.dart';
import 'package:fitness_app/features/chat/widgets/e2ee_security_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildChatScreen({
    String conversationId = 'conv_trainer-1',
    String trainerId = 'trainer-1',
    String trainerName = 'Bob Trainer',
    String? trainerUserId = 'user-coach-bob',
    ChatBloc? chatBloc,
    bool? isTemplateCoach,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: ChatScreen(
        conversationId: conversationId,
        trainerId: trainerId,
        trainerName: trainerName,
        trainerUserId: trainerUserId,
        chatBloc: chatBloc,
        isTemplateCoach: isTemplateCoach,
      ),
    );
  }

  group('ChatScreen UI & Resilience Tests', () {
    testWidgets(
      'ChatScreen renders completely without ancestor ChatBloc (zero ProviderNotFoundException)',
      (tester) async {
        // Pump directly without BlocProvider in ancestor tree
        await tester.pumpWidget(buildChatScreen());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Must not crash or display Flutter error
        expect(tester.takeException(), isNull);

        // Header elements render
        expect(find.text('Bob Trainer'), findsOneWidget);
        expect(find.byType(E2eeSecurityBanner), findsWidgets);

        // Body must NOT be empty or collapsed
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byTooltip('Send Encrypted Message'), findsOneWidget);
      },
    );

    testWidgets(
      'Displays DEMO TEMPLATE COACH banner specifying coach cannot reply',
      (tester) async {
        await tester.pumpWidget(buildChatScreen(trainerName: 'Bob Trainer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Banner and disclaimer check
        expect(
          find.byKey(const Key('template_coach_disclaimer_banner')),
          findsOneWidget,
        );
        expect(find.text('DEMO TEMPLATE COACH'), findsOneWidget);
        expect(find.text('CANNOT REPLY'), findsOneWidget);
        expect(
          find.textContaining('Bob Trainer is a demonstration template coach'),
          findsOneWidget,
        );
        expect(
          find.textContaining('cannot reply in real-time'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Renders seeded mock messages for Bob Trainer in chat room',
      (tester) async {
        await tester.pumpWidget(buildChatScreen(
          conversationId: 'conv-mock-1',
          trainerId: 'trainer-1',
          trainerName: 'Bob Trainer',
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // ChatMessageBubble widgets should appear
        expect(find.byType(ChatMessageBubble), findsWidgets);
        expect(
          find.text('Great session today! Remember to hit 150g protein.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Renders clean empty state when no messages exist for trainer',
      (tester) async {
        await tester.pumpWidget(buildChatScreen(
          conversationId: 'conv_empty_test_trainer',
          trainerId: 'trainer-empty',
          trainerName: 'Empty Coach',
          trainerUserId: 'user-coach-empty',
          isTemplateCoach: true,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Say hello to Empty Coach!'), findsOneWidget);
        expect(
          find.textContaining('Say hello to your coach! Messages are end-to-end encrypted'),
          findsOneWidget,
        );
        expect(
          find.textContaining('cannot reply in real-time'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'Typing text enables send button and adds outgoing bubble on send',
      (tester) async {
        await tester.pumpWidget(buildChatScreen());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        // Enter text
        await tester.enterText(textFieldFinder, 'Testing encrypted coach message');
        await tester.pump();

        // Send button should now be enabled
        final sendButton = find.byTooltip('Send Encrypted Message');
        await tester.tap(sendButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Message should appear in chat bubbles list
        expect(find.text('Testing encrypted coach message'), findsOneWidget);
      },
    );

    testWidgets(
      'Real non-template coach does NOT render template coach disclaimer banner',
      (tester) async {
        await tester.pumpWidget(buildChatScreen(
          conversationId: 'conv_real_123',
          trainerId: 'real_trainer_uuid_456',
          trainerName: 'Marcus Real Coach',
          trainerUserId: 'user-real-789',
          isTemplateCoach: false,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('template_coach_disclaimer_banner')),
          findsNothing,
        );
        expect(find.text('DEMO TEMPLATE COACH'), findsNothing);
      },
    );

    testWidgets(
      'Narrow viewport (300px width) renders template banner without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(300, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        FlutterErrorDetails? caughtDetails;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
        };

        await tester.pumpWidget(buildChatScreen(trainerName: 'Bob Trainer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        FlutterError.onError = oldHandler;

        if (caughtDetails != null) {
          fail('EXACT ERROR:\n${caughtDetails.toString()}');
        }
        expect(
          find.byKey(const Key('template_coach_disclaimer_banner')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Sending message to template coach displays floating disclaimer snackbar',
      (tester) async {
        await tester.pumpWidget(buildChatScreen(trainerName: 'Bob Trainer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final textFieldFinder = find.byType(TextField);
        await tester.enterText(textFieldFinder, 'Hello coach Bob!');
        await tester.pump();

        final sendButton = find.byTooltip('Send Encrypted Message');
        await tester.tap(sendButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Bob Trainer is a template coach and cannot reply in real-time.'),
          findsOneWidget,
        );
      },
    );
  });
}
