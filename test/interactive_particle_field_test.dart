import 'package:fitness_app/core/widgets/interactive_particle_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InteractiveParticleField Tests', () {
    testWidgets('renders custom painter and child without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: InteractiveParticleField(
                child: Center(child: Text('PulseFit Ambient')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('PulseFit Ambient'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('responds to mouse hover events and wakes ticker', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: InteractiveParticleField(
                enableHeartbeatPulse: false,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(const Offset(200, 200));
      await tester.pump();

      // Ensure custom paint renders while interacting
      expect(find.byType(CustomPaint), findsWidgets);

      // Move away
      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('responds to mobile touch drag and screen resize', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320, // Mobile viewport width
              height: 568, // Mobile viewport height
              child: InteractiveParticleField(),
            ),
          ),
        ),
      );

      // Simulate finger touch and drag on mobile screen
      final touchGesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await touchGesture.down(const Offset(160, 280));
      await tester.pump();
      await touchGesture.moveTo(const Offset(180, 300));
      await tester.pump();
      await touchGesture.up();
      await tester.pump();

      // Simulate device rotation / screen resizing to tablet/desktop
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024,
              height: 768,
              child: InteractiveParticleField(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(InteractiveParticleField), findsOneWidget);
    });
  });
}
