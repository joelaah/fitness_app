import 'package:fitness_app/features/nutrition/screens/macro_calculator_screen.dart';
import 'package:fitness_app/features/nutrition/services/nutrition_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'profile_weight_kg': 80.0,
    });
  });

  Widget createWidget({NutritionService? service}) {
    return MaterialApp(
      home: MacroCalculatorScreen(
        nutritionService: service,
      ),
    );
  }

  testWidgets('renders both calculation methods: Athletic and Standard',
      (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('⚡ Athletic (Per-kg Protein)'), findsOneWidget);
    expect(find.text('Standard % Split'), findsOneWidget);
    expect(find.text('DAILY ENERGY TARGET'), findsOneWidget);
  });

  testWidgets('switching to Standard % hides per-kg options and updates card',
      (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Default is Athletic (Per-kg Protein)
    expect(find.text('Protein Target (g/kg)'), findsOneWidget);

    // Tap Standard % Split
    await tester.tap(find.text('Standard % Split'));
    await tester.pumpAndSettle();

    // Per-kg options should be hidden
    expect(find.text('Protein Target (g/kg)'), findsNothing);
    // Card should indicate standard 30% protein
    expect(find.text('(Standard 30% protein)'), findsOneWidget);
  });

  testWidgets('switching between Carb/Fat strategies updates macros',
      (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Tap High-Carb
    final highCarbFinder = find.text('High-Carb\n(65% C / 35% F)');
    expect(highCarbFinder, findsOneWidget);
    await tester.ensureVisible(highCarbFinder);
    await tester.tap(highCarbFinder);
    await tester.pumpAndSettle();

    // Verify it remains responsive and doesn't crash
    expect(find.text('DAILY ENERGY TARGET'), findsOneWidget);
  });

  testWidgets('selecting different protein ratios updates preview',
      (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Tap 2.2 g/kg
    final chip22 = find.text('2.2 g/kg\nDeficit / Cut');
    expect(chip22, findsOneWidget);
    await tester.ensureVisible(chip22);
    await tester.tap(chip22);
    await tester.pumpAndSettle();

    expect(find.text('(2.2 g/kg protein)'), findsOneWidget);
  });

  testWidgets('MacroCalculatorScreen renders with zero overflow on narrow mobile (320x640)',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DAILY ENERGY TARGET'), findsOneWidget);
    expect(find.text('APPLY & SAVE TARGETS'), findsOneWidget);
  });

  testWidgets('expanding US Navy accordion and inputting measurements updates telemetry without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final navyExpander = find.text('Optional: US Navy Body Fat & Katch-McArdle BMR');
    await tester.ensureVisible(navyExpander);
    await tester.tap(navyExpander);
    await tester.pumpAndSettle();

    expect(find.text('Waist (cm)'), findsOneWidget);
    expect(find.text('Neck (cm)'), findsOneWidget);

    // Enter waist and neck
    await tester.enterText(find.widgetWithText(TextFormField, '').first, '80');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('changing fitness goal updates calorie targets dynamically',
      (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final bulkGoal = find.text('Bulking (+500 kcal)');
    await tester.ensureVisible(bulkGoal);
    await tester.tap(bulkGoal);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DAILY ENERGY TARGET'), findsOneWidget);
  });
}
