import 'dart:io';

import 'package:fitness_app/features/payments/screens/razorpay_sandbox_dialog.dart';
import 'package:fitness_app/features/payments/services/payment_signature_helper.dart';
import 'package:fitness_app/features/payments/services/razorpay_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web Release Build Artifact & Base Href Empirical Oracles', () {
    test(
      'build/web/index.html exists and contains valid base href /fitness_app/',
      () {
        final indexHtmlFile = File('build/web/index.html');
        expect(
          indexHtmlFile.existsSync(),
          isTrue,
          reason: 'build/web/index.html must exist after release build',
        );

        final content = indexHtmlFile.readAsStringSync();
        expect(
          content.contains('<base href="/fitness_app/">'),
          isTrue,
          reason: 'index.html must contain exactly <base href="/fitness_app/">',
        );
        expect(
          content.contains(r'$FLUTTER_BASE_HREF'),
          isFalse,
          reason: r'Placeholder $FLUTTER_BASE_HREF must be resolved',
        );
      },
    );

    test('build/web/main.dart.js exists and is non-empty (>1MB)', () {
      final mainJsFile = File('build/web/main.dart.js');
      expect(
        mainJsFile.existsSync(),
        isTrue,
        reason: 'build/web/main.dart.js must exist',
      );

      final length = mainJsFile.lengthSync();
      expect(
        length,
        greaterThan(1024 * 1024),
        reason: 'main.dart.js must be larger than 1MB (actual: $length bytes)',
      );
    });

    test(
      'build/web/assets/fonts/MaterialIcons-Regular.otf was tree-shaken <50KB',
      () {
        final fontFile =
            File('build/web/assets/fonts/MaterialIcons-Regular.otf');
        expect(
          fontFile.existsSync(),
          isTrue,
          reason: 'MaterialIcons font asset must be packaged in fonts/',
        );

        final length = fontFile.lengthSync();
        // Original size is ~1.64 MB. Tree-shaken font is ~22 KB.
        expect(
          length,
          greaterThan(1000),
          reason: 'MaterialIcons font must be non-empty',
        );
        expect(
          length,
          lessThan(100 * 1024),
          reason: 'Tree-shaking must reduce size <100KB (actual: $length B)',
        );
      },
    );

    test('build/web service worker and bootstrap scripts exist', () {
      final bootstrap = File('build/web/flutter_bootstrap.js');
      final sw = File('build/web/flutter_service_worker.js');
      expect(bootstrap.existsSync(), isTrue);
      expect(sw.existsSync(), isTrue);
    });
  });

  group('Milestone 6 Icon Glyph Integrity & Tree-Shaking Validation', () {
    test(
      'All required icons possess valid non-null codepoints in MaterialIcons',
      () {
        final icons = <String, IconData>{
          'sports_gymnastics_outlined': Icons.sports_gymnastics_outlined,
          'sports_gymnastics_rounded': Icons.sports_gymnastics_rounded,
          'bolt_rounded': Icons.bolt_rounded,
          'chat_bubble_outline_rounded': Icons.chat_bubble_outline_rounded,
          'receipt_long_outlined': Icons.receipt_long_outlined,
        };

        for (final entry in icons.entries) {
          expect(
            entry.value.codePoint,
            isPositive,
            reason: '${entry.key} must have a valid positive codepoint',
          );
          expect(
            entry.value.fontFamily,
            equals('MaterialIcons'),
            reason: '${entry.key} must belong to MaterialIcons font family',
          );
        }
      },
    );

    testWidgets(
      'Renders all required M6 icons without layout or glyph errors',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Icon(Icons.sports_gymnastics_outlined),
                  Icon(Icons.sports_gymnastics_rounded),
                  Icon(Icons.bolt_rounded),
                  Icon(Icons.chat_bubble_outline_rounded),
                  Icon(Icons.receipt_long_outlined),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.sports_gymnastics_outlined), findsOneWidget);
        expect(find.byIcon(Icons.sports_gymnastics_rounded), findsOneWidget);
        expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      },
    );
  });

  group('RazorpayBridgeWeb Sandbox Modal Cross-Platform Compatibility', () {
    const compactTestOptions = RazorpayCheckoutOptions(
      keyId: 'rzp_test_mockKey123',
      orderId: 'order_999',
      amount: 1500,
      name: 'PulseFit',
      description: 'Session',
    );

    testWidgets(
      'RazorpaySandboxDialog renders tabs & order summary on desktop view',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1200, 900)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final loggedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = loggedErrors.add;

        try {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: RazorpaySandboxDialog(options: compactTestOptions),
              ),
            ),
          );
          await tester.pump();

          // Header branding
          expect(find.text('Razorpay'), findsOneWidget);
          expect(find.text('SECURE'), findsOneWidget);
          expect(find.text('TEST MODE'), findsOneWidget);

          // Order info
          expect(find.text('PulseFit'), findsOneWidget);
          expect(find.text('Session'), findsOneWidget);
          expect(find.text('Order: order_999'), findsOneWidget);
          expect(find.text('₹1500.00'), findsOneWidget);

          // Tab navigation
          expect(find.text('UPI / QR'), findsOneWidget);
          expect(find.text('Cards'), findsOneWidget);
          expect(find.text('NetBanking'), findsOneWidget);

          // Switch to Cards tab
          await tester.tap(find.text('Cards'));
          await tester.pumpAndSettle();
          expect(find.text('Test Cards Preset:'), findsOneWidget);

          // Switch to NetBanking tab
          await tester.tap(find.text('NetBanking'));
          await tester.pumpAndSettle();
          expect(find.text('Select Simulated Retail Bank:'), findsOneWidget);
          expect(find.text('HDFC Bank'), findsOneWidget);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      'RazorpayBridgeWeb: Success simulation returns valid HMAC signature',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1200, 900)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        PaymentSuccessResponse? successPayload;
        PaymentFailureResponse? failurePayload;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    RazorpayBridgeWeb().openCheckout(
                      context: ctx,
                      options: compactTestOptions,
                      onSuccess: (res) => successPayload = res,
                      onError: (err) => failurePayload = err,
                    );
                  },
                  child: const Text('Open Checkout'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Launch modal
        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        expect(find.byType(RazorpaySandboxDialog), findsOneWidget);

        // Tap Simulate Payment Success
        final successBtn = find.text('Simulate Payment Success (₹1500)');
        expect(successBtn, findsOneWidget);
        await tester.tap(successBtn);
        await tester.pumpAndSettle();

        // Modal closed, success callback invoked
        expect(find.byType(RazorpaySandboxDialog), findsNothing);
        expect(failurePayload, isNull);
        expect(successPayload, isNotNull);
        expect(successPayload!.orderId, equals('order_999'));
        expect(successPayload!.paymentId.startsWith('pay_test_'), isTrue);

        // Verify HMAC-SHA256 signature validity against PaymentSignatureHelper
        final expectedSig = PaymentSignatureHelper.computeRazorpaySignature(
          orderId: successPayload!.orderId,
          paymentId: successPayload!.paymentId,
        );
        expect(successPayload!.signature, equals(expectedSig));
      },
    );

    testWidgets(
      'RazorpayBridgeWeb: Decline simulation invokes codePaymentFailed',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1200, 900)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        PaymentSuccessResponse? successPayload;
        PaymentFailureResponse? failurePayload;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    RazorpayBridgeWeb().openCheckout(
                      context: ctx,
                      options: compactTestOptions,
                      onSuccess: (res) => successPayload = res,
                      onError: (err) => failurePayload = err,
                    );
                  },
                  child: const Text('Open Checkout'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        final declineBtn = find.text('Simulate Decline');
        expect(declineBtn, findsOneWidget);
        await tester.tap(declineBtn);
        await tester.pumpAndSettle();

        expect(successPayload, isNull);
        expect(failurePayload, isNotNull);
        expect(
          failurePayload!.code,
          equals(PaymentFailureResponse.codePaymentFailed),
        );
        expect(failurePayload!.message.contains('declined'), isTrue);
      },
    );

    testWidgets(
      'RazorpayBridgeWeb: Cancel simulation invokes codeCancelled',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1200, 900)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        PaymentSuccessResponse? successPayload;
        PaymentFailureResponse? failurePayload;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    RazorpayBridgeWeb().openCheckout(
                      context: ctx,
                      options: compactTestOptions,
                      onSuccess: (res) => successPayload = res,
                      onError: (err) => failurePayload = err,
                    );
                  },
                  child: const Text('Open Checkout'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Open Checkout'));
        await tester.pumpAndSettle();

        final cancelBtn = find.text('Cancel Payment');
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(successPayload, isNull);
        expect(failurePayload, isNotNull);
        expect(
          failurePayload!.code,
          equals(PaymentFailureResponse.codeCancelled),
        );
        expect(failurePayload!.isCancelled, isTrue);
      },
    );

    testWidgets(
      'Adversarial Stress Test: Detects unconstrained RenderFlex overflow',
      (tester) async {
        const longOptions = RazorpayCheckoutOptions(
          keyId: 'rzp_test_mockKey123',
          orderId: 'order_mock_test_999888777',
          amount: 1500,
          name: 'PulseFit AI Personal Coaching',
          description:
              'Elite Strength & Conditioning Session with Coach Marcus',
        );

        final loggedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = loggedErrors.add;

        try {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: RazorpaySandboxDialog(options: longOptions),
              ),
            ),
          );
          await tester.pump();
        } finally {
          FlutterError.onError = originalOnError;
        }

        // Assert that empirical stress-test surfaced the RenderFlex overflow
        final hasOverflow = loggedErrors.any(
          (e) => e.toString().contains('A RenderFlex overflowed by'),
        );
        expect(
          hasOverflow,
          isTrue,
          reason: 'RazorpaySandboxDialog unconstrained Row/Column overflowed',
        );
      },
    );
  });
}
