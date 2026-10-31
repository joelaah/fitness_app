import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Zero Hub inspired motion physics and spring curves.
///
/// Designed for high frame rate, organic liquid responses to pointer and
/// touch interactions without linear mechanical jank.
class ZeroMotionCurves {
  const ZeroMotionCurves._();

  /// Zero Hub's exact cubic-bezier easing curve (`cubic-bezier(0.16, 1, 0.3, 1)`).
  /// Delivers instant initial velocity with silky, ultra-smooth settling.
  static const Curve fluidOut = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Snappy spring curve for micro-interactions and quick card pops.
  static const Curve snappySpring = Cubic(0.05, 0.9, 0.1, 1.0);

  /// Smooth liquid ease for modal reveals and backdrop blurs.
  static const Curve liquidEaseInOut = Cubic(0.65, 0.0, 0.35, 1.0);
}

/// Physics spring presets calibrated for 3D tilt, card lift, and particle return.
class SpringPhysicsPresets {
  const SpringPhysicsPresets._();

  /// Snappy spring with negligible overshoot, perfect for card hover releases.
  static const SpringDescription snappy = SpringDescription(
    mass: 1.0,
    stiffness: 240.0,
    damping: 22.0,
  );

  /// Bouncy liquid spring with subtle elastic rebound for energetic feedback.
  static const SpringDescription liquidBounce = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 14.0,
  );

  /// Gentle organic settling spring for large canvas ambient elements.
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 120.0,
    damping: 18.0,
  );
}

/// A lightweight, single-ticker controller that drives values using real-time
/// [SpringSimulation] physics rather than rigid duration tweens.
class SpringMotionController extends ChangeNotifier {
  SpringMotionController({
    required TickerProvider vsync,
    double initialValue = 0.0,
    this.defaultSpring = SpringPhysicsPresets.snappy,
  })  : _value = initialValue,
        _targetValue = initialValue {
    _ticker = vsync.createTicker(_tick);
  }

  final SpringDescription defaultSpring;
  late final Ticker _ticker;

  double _value;
  double _targetValue;
  double _velocity = 0.0;
  SpringSimulation? _simulation;

  /// Current physical value of the spring.
  double get value => _value;

  /// The target resting value.
  double get targetValue => _targetValue;

  /// Current velocity of the spring simulation.
  double get velocity => _velocity;

  /// Whether the spring is actively simulating motion.
  bool get isAnimating => _ticker.isActive;

  /// Springs to [target] from the current position and velocity.
  void springTo(
    double target, {
    SpringDescription? spring,
    double? initialVelocity,
  }) {
    _targetValue = target;
    final startVelocity = initialVelocity ?? _velocity;
    _simulation = SpringSimulation(
      spring ?? defaultSpring,
      _value,
      target,
      startVelocity,
    );
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  /// Instantly teleports to [target] and halts all momentum.
  void snapTo(double target) {
    _targetValue = target;
    _value = target;
    _velocity = 0.0;
    _simulation = null;
    if (_ticker.isActive) {
      _ticker.stop();
    }
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    if (_simulation == null) {
      _ticker.stop();
      return;
    }

    final double seconds = elapsed.inMicroseconds / 1000000.0;
    _value = _simulation!.x(seconds);
    _velocity = _simulation!.dx(seconds);

    if (_simulation!.isDone(seconds) || (_value - _targetValue).abs() < 0.001) {
      _value = _targetValue;
      _velocity = 0.0;
      _simulation = null;
      _ticker.stop();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
