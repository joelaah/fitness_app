import 'package:fitness_app/core/theme/spring_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestSpringWidget extends StatefulWidget {
  const _TestSpringWidget({required this.onCreated});
  final void Function(SpringMotionController controller) onCreated;

  @override
  State<_TestSpringWidget> createState() => _TestSpringWidgetState();
}

class _TestSpringWidgetState extends State<_TestSpringWidget>
    with SingleTickerProviderStateMixin {
  late final SpringMotionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SpringMotionController(
      vsync: this,
      initialValue: 0.0,
    );
    widget.onCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZeroMotionCurves Tests', () {
    test('fluidOut curve conforms to cubic-bezier bounds', () {
      expect(ZeroMotionCurves.fluidOut.transform(0.0), equals(0.0));
      expect(ZeroMotionCurves.fluidOut.transform(1.0), equals(1.0));
      expect(ZeroMotionCurves.fluidOut.transform(0.5), greaterThan(0.7));
    });

    test('snappySpring curve provides rapid front-loaded response', () {
      expect(ZeroMotionCurves.snappySpring.transform(0.0), equals(0.0));
      expect(ZeroMotionCurves.snappySpring.transform(1.0), equals(1.0));
      expect(ZeroMotionCurves.snappySpring.transform(0.3), greaterThan(0.75));
    });
  });

  group('SpringMotionController Tests', () {
    testWidgets('springs from initial value to target smoothly', (tester) async {
      SpringMotionController? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestSpringWidget(
              onCreated: (c) => controller = c,
            ),
          ),
        ),
      );

      expect(controller, isNotNull);
      expect(controller!.value, equals(0.0));
      expect(controller!.isAnimating, isFalse);

      controller!.springTo(100.0);
      expect(controller!.targetValue, equals(100.0));
      expect(controller!.isAnimating, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller!.value, greaterThan(0.0));

      // Allow spring to complete
      await tester.pump(const Duration(milliseconds: 1000));
      expect(controller!.value, closeTo(100.0, 0.05));
      expect(controller!.isAnimating, isFalse);

      // Test snapTo
      controller!.snapTo(50.0);
      expect(controller!.value, equals(50.0));
      expect(controller!.isAnimating, isFalse);
    });
  });
}
