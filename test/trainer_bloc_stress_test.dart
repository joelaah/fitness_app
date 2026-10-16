import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_bloc.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_event.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_state.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_discovery_screen.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock service returning empty trainer catalog
class EmptyMockTrainerService extends TrainerService {
  @override
  Future<List<TrainerProfile>> getTrainers({
    TrainerFilterCriteria? filter,
    bool forceRefresh = false,
  }) async {
    return <TrainerProfile>[];
  }

  @override
  Future<TrainerProfile?> getMyTrainerProfile() async => null;
}

/// Mock service simulating network latency for race condition testing
class DelayedMockTrainerService extends TrainerService {
  DelayedMockTrainerService({
    this.delay = const Duration(milliseconds: 100),
    List<TrainerProfile>? catalog,
  }) : _catalog =
           catalog ??
           <TrainerProfile>[
             const TrainerProfile(
               id: 't-1',
               userId: 'u-1',
               displayName: 'Coach Speed',
               bio: 'Fast sprinter',
               specialties: <String>['HIIT', 'Strength'],
               hourlyRate: 1000,
               rating: 4.9,
             ),
             const TrainerProfile(
               id: 't-2',
               userId: 'u-2',
               displayName: 'Coach Heavy',
               bio: 'Heavy lifter',
               specialties: <String>['Powerlifting', 'Strength'],
               hourlyRate: 2000,
               rating: 4.8,
             ),
           ];

  final Duration delay;
  final List<TrainerProfile> _catalog;

  @override
  Future<List<TrainerProfile>> getTrainers({
    TrainerFilterCriteria? filter,
    bool forceRefresh = false,
  }) async {
    await Future<void>.delayed(delay);
    return List<TrainerProfile>.of(_catalog);
  }

  @override
  Future<TrainerProfile?> getMyTrainerProfile() async => null;
}

void main() {
  group('1. Empty Catalog & Edge States Stress Tests', () {
    test(
      'LoadTrainers on empty catalog emits TrainerLoaded with empty lists',
      () async {
        final bloc = TrainerBloc(trainerService: EmptyMockTrainerService());
        expect(bloc.state, isA<TrainerInitial>());

        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerLoaded>());

        final loaded = states[1] as TrainerLoaded;
        expect(loaded.allTrainers, isEmpty);
        expect(loaded.filteredTrainers, isEmpty);
        expect(loaded.hasActiveFilter, isFalse);

        await sub.cancel();
        await bloc.close();
      },
    );

    test(
      'FilterTrainers on empty catalog preserves empty list without error',
      () async {
        final bloc = TrainerBloc(trainerService: EmptyMockTrainerService());
        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        bloc.add(
          const FilterTrainers(
            TrainerFilterCriteria(
              searchQuery: 'NonExistent',
              selectedSpecialty: 'Yoga',
              maxHourlyRate: 500,
              minRating: 4.5,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state, isA<TrainerLoaded>());
        final loaded = bloc.state as TrainerLoaded;
        expect(loaded.filteredTrainers, isEmpty);
        expect(loaded.hasActiveFilter, isTrue);

        // Reset
        bloc.add(const ResetTrainerFilter());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final resetState = bloc.state as TrainerLoaded;
        expect(resetState.filteredTrainers, isEmpty);
        expect(resetState.hasActiveFilter, isFalse);

        await bloc.close();
      },
    );
  });

  group('2. Rapid Filter Switching & Event Flood Stress Tests', () {
    test(
      'dispatches 100 rapid sequential filter changes without stream errors',
      () async {
        final bloc = TrainerBloc();
        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(bloc.state, isA<TrainerLoaded>());

        final emittedStates = <TrainerState>[];
        final sub = bloc.stream.listen(emittedStates.add);

        final specialties = <String>[
          'Strength',
          'Yoga',
          'HIIT',
          'Mobility',
          'Powerlifting',
          'Nutrition',
          'All',
        ];

        for (var i = 0; i < 100; i++) {
          final spec = specialties[i % specialties.length];
          bloc.add(
            FilterTrainers(
              TrainerFilterCriteria(
                searchQuery: i % 2 == 0 ? 'Coach' : null,
                selectedSpecialty: spec,
                maxHourlyRate: 500.0 + (i * 20.0),
                minRating: 4.0 + (i % 10) * 0.1,
              ),
            ),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(emittedStates.length, greaterThan(0));
        expect(bloc.state, isA<TrainerLoaded>());

        final finalState = bloc.state as TrainerLoaded;
        // Last iteration was i = 99
        final expectedSpecialty = specialties[99 % specialties.length];
        expect(finalState.currentFilter.selectedSpecialty, expectedSpecialty);
        expect(finalState.currentFilter.maxHourlyRate, 500.0 + (99 * 20.0));

        await sub.cancel();
        await bloc.close();
      },
    );

    test(
      'rapid alternating FilterTrainers and ResetTrainerFilter maintains consistency',
      () async {
        final bloc = TrainerBloc();
        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 80));

        for (var i = 0; i < 50; i++) {
          bloc.add(
            const FilterTrainers(
              TrainerFilterCriteria(selectedSpecialty: 'Yoga'),
            ),
          );
          bloc.add(const ResetTrainerFilter());
        }

        await Future<void>.delayed(const Duration(milliseconds: 150));

        final state = bloc.state as TrainerLoaded;
        expect(state.currentFilter.isEmpty, isTrue);
        expect(state.filteredTrainers.length, state.allTrainers.length);

        await bloc.close();
      },
    );
  });

  group('3. Unicode, RTL, Emoji & Query String Boundary Tests', () {
    final testTrainers = <TrainerProfile>[
      const TrainerProfile(
        id: 't-unicode-1',
        userId: 'u-1',
        displayName: 'Лилия Смирнова',
        bio: 'Сертифицированный тренер по силовой подготовке и пауэрлифтингу.',
        specialties: <String>['Сила', 'Пауэрлифтинг', 'Strength'],
        hourlyRate: 1200,
        rating: 4.9,
      ),
      const TrainerProfile(
        id: 't-unicode-2',
        userId: 'u-2',
        displayName: '张伟 🏋️‍♂️',
        bio: '国家级健身教练，专注力量训练与减脂 🔥💪',
        specialties: <String>['力量', '减脂', 'HIIT'],
        hourlyRate: 1800,
        rating: 4.95,
      ),
      const TrainerProfile(
        id: 't-unicode-3',
        userId: 'u-3',
        displayName: 'طارق المصري',
        bio: 'مدرب لياقة بدنية وبناء أجسام معتمد دولياً',
        specialties: <String>['كمال أجسام', 'تغذية', 'Mobility'],
        hourlyRate: 2000,
        rating: 4.85,
      ),
      const TrainerProfile(
        id: 't-unicode-4',
        userId: 'u-4',
        displayName: 'Jürgen Müller',
        bio: 'Ausdauer- und Hypertrophie-Training für Profis',
        specialties: <String>['Hypertrophie', 'Ausdauer'],
        hourlyRate: 1500,
        rating: 4.7,
      ),
    ];

    test('matches Cyrillic search queries case-insensitively', () {
      const criteria = TrainerFilterCriteria(searchQuery: 'лилия');
      final matched = testTrainers.where(criteria.matches).toList();
      expect(matched.length, 1);
      expect(matched.first.id, 't-unicode-1');

      const upperCriteria = TrainerFilterCriteria(searchQuery: 'ПАУЭРЛИФТИНГ');
      final upperMatched = testTrainers.where(upperCriteria.matches).toList();
      expect(upperMatched.length, 1);
      expect(upperMatched.first.id, 't-unicode-1');
    });

    test('matches CJK search queries and emojis', () {
      const cjkCriteria = TrainerFilterCriteria(searchQuery: '张伟');
      final cjkMatched = testTrainers.where(cjkCriteria.matches).toList();
      expect(cjkMatched.length, 1);
      expect(cjkMatched.first.id, 't-unicode-2');

      const emojiCriteria = TrainerFilterCriteria(searchQuery: '🔥');
      final emojiMatched = testTrainers.where(emojiCriteria.matches).toList();
      expect(emojiMatched.length, 1);
      expect(emojiMatched.first.id, 't-unicode-2');
    });

    test('matches Arabic RTL search queries', () {
      const arabicCriteria = TrainerFilterCriteria(searchQuery: 'طارق');
      final arabicMatched = testTrainers.where(arabicCriteria.matches).toList();
      expect(arabicMatched.length, 1);
      expect(arabicMatched.first.id, 't-unicode-3');
    });

    test('matches accented European characters (umlauts, etc.)', () {
      const germanCriteria = TrainerFilterCriteria(searchQuery: 'jürgen');
      final germanMatched = testTrainers.where(germanCriteria.matches).toList();
      expect(germanMatched.length, 1);
      expect(germanMatched.first.id, 't-unicode-4');
    });

    test('handles extreme string sizes (10,000 chars) without crashing', () {
      final hugeQuery = 'A' * 10000;
      final criteria = TrainerFilterCriteria(searchQuery: hugeQuery);
      final matched = testTrainers.where(criteria.matches).toList();
      expect(matched, isEmpty);
    });

    test('handles regex special characters safely as literal strings', () {
      final specialQueries = <String>[
        r'.*',
        r'[a-zA-Z0-9]+',
        r'(?=.*[0-9])',
        r'^\s*$',
        r'\d+\.\d+',
        r'${test}',
        r'"><script>alert(1)</script>',
        r'DROP TABLE trainer_profiles;--',
        r'%',
        r'_',
      ];

      for (final query in specialQueries) {
        final criteria = TrainerFilterCriteria(searchQuery: query);
        expect(
          () => testTrainers.where(criteria.matches).toList(),
          returnsNormally,
        );
      }
    });

    test(
      'handles whitespace-only queries by ignoring them (non-filtering)',
      () {
        const spacesCriteria = TrainerFilterCriteria(searchQuery: '   \t  \n ');
        final matched = testTrainers.where(spacesCriteria.matches).toList();
        expect(matched.length, testTrainers.length);
      },
    );
  });

  group('4. Extreme Pricing Sliders & Precision Math Tests', () {
    final trainers = <TrainerProfile>[
      const TrainerProfile(
        id: 't-free',
        userId: 'u-0',
        displayName: 'Free Coach',
        bio: 'Community volunteer',
        hourlyRate: 0.0,
      ),
      const TrainerProfile(
        id: 't-cheap',
        userId: 'u-1',
        displayName: 'Budget Coach',
        bio: 'Affordable sessions',
        hourlyRate: 50.0,
      ),
      const TrainerProfile(
        id: 't-expensive',
        userId: 'u-2',
        displayName: 'Elite Coach',
        bio: 'Celebrity trainer',
        hourlyRate: 50000.0,
      ),
    ];

    test('maxHourlyRate = 0.0 retains only 0.0 rate trainers', () {
      const criteria = TrainerFilterCriteria(maxHourlyRate: 0.0);
      final matched = trainers.where(criteria.matches).toList();
      expect(matched.length, 1);
      expect(matched.first.id, 't-free');
    });

    test('negative maxHourlyRate filters out all non-negative trainers', () {
      const criteria = TrainerFilterCriteria(maxHourlyRate: -10.0);
      final matched = trainers.where(criteria.matches).toList();
      expect(matched, isEmpty);
    });

    test('extremely large maxHourlyRate retains all trainers', () {
      const criteria = TrainerFilterCriteria(maxHourlyRate: 1000000.0);
      final matched = trainers.where(criteria.matches).toList();
      expect(matched.length, trainers.length);
    });

    test('extreme or unusual rating thresholds', () {
      const zeroRatingCriteria = TrainerFilterCriteria(minRating: 0.0);
      expect(
        trainers.where(zeroRatingCriteria.matches).length,
        trainers.length,
      );

      const highRatingCriteria = TrainerFilterCriteria(minRating: 5.01);
      expect(trainers.where(highRatingCriteria.matches), isEmpty);

      const negativeRatingCriteria = TrainerFilterCriteria(minRating: -5.0);
      expect(
        trainers.where(negativeRatingCriteria.matches).length,
        trainers.length,
      );
    });

    test(
      'Platform fee and net payout math: sum equals hourlyRate across test values',
      () {
        // Testing precision and rounding behavior
        final testRates = <double>[
          100.0,
          1500.0,
          800.0,
          2500.0,
          50.0,
          99.99,
          15.05,
          10.50,
          0.0,
        ];

        for (final rate in testRates) {
          final profile = TrainerProfile(
            id: 'test',
            userId: 'u',
            hourlyRate: rate,
            platformFeePct: 10.0,
          );

          final fee = profile.platformFeeAmountPerHour;
          final payout = profile.trainerPayoutPerHour;
          final sum = double.parse((fee + payout).toStringAsFixed(2));

          // Let us empirically check if sum == rate
          // Note: Floating point or independent rounding could diverge by 0.01
          final diff = (sum - rate).abs();
          expect(
            diff,
            lessThanOrEqualTo(0.02),
            reason: 'Rate $rate: fee=$fee, payout=$payout, sum=$sum',
          );
        }
      },
    );
  });

  group('5. Concurrency & State Machine Race Condition Tests', () {
    test(
      'FilterTrainers dispatched while LoadTrainers is in-flight: verifies filter retention or drop',
      () async {
        // Setup a service with 80ms delay
        final delayedService = DelayedMockTrainerService(
          delay: const Duration(milliseconds: 80),
        );
        final bloc = TrainerBloc(trainerService: delayedService);

        // Start loading
        bloc.add(const LoadTrainers());

        // Give 20ms for LoadTrainers to emit TrainerLoading
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(bloc.state, isA<TrainerLoading>());

        // User dispatches a filter while loading is still in progress!
        bloc.add(
          const FilterTrainers(
            TrainerFilterCriteria(selectedSpecialty: 'Powerlifting'),
          ),
        );

        // Wait for delayed LoadTrainers to finish (80ms + buffer)
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(bloc.state, isA<TrainerLoaded>());
        final loadedState = bloc.state as TrainerLoaded;

        // OBSERVATION CHECK:
        // Does loadedState reflect the filter dispatched during loading?
        // In TrainerBloc._onFilterTrainers: if (state is TrainerLoaded) ...
        // If state was TrainerLoading, the filter event was silently dropped!
        // Let's document what happens empirically:
        final filterWasPreserved =
            loadedState.currentFilter.selectedSpecialty == 'Powerlifting';
        expect(
          filterWasPreserved,
          isTrue,
          reason:
              'Filter is retained across in-flight loading cycles.',
        );

        await bloc.close();
      },
    );

    test(
      'SelectTrainer dispatched while LoadTrainers is in-flight: verifies selection retention or drop',
      () async {
        final delayedService = DelayedMockTrainerService(
          delay: const Duration(milliseconds: 80),
        );
        final bloc = TrainerBloc(trainerService: delayedService);

        const targetTrainer = TrainerProfile(
          id: 't-target',
          userId: 'u-target',
          displayName: 'Target Coach',
          hourlyRate: 1500,
        );

        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(bloc.state, isA<TrainerLoading>());

        // User selects a trainer while reload is pending
        bloc.add(const SelectTrainer(targetTrainer));

        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(bloc.state, isA<TrainerLoaded>());
        final loadedState = bloc.state as TrainerLoaded;
        expect(
          loadedState.selectedTrainer,
          equals(targetTrainer),
          reason:
              'SelectTrainer is retained across in-flight loading cycles.',
        );

        await bloc.close();
      },
    );

    test(
      'Multiple concurrent LoadTrainers: later events do not throw or corrupt state',
      () async {
        final delayedService = DelayedMockTrainerService(
          delay: const Duration(milliseconds: 50),
        );
        final bloc = TrainerBloc(trainerService: delayedService);

        // Spam 5 LoadTrainers concurrently
        for (var i = 0; i < 5; i++) {
          bloc.add(const LoadTrainers(forceRefresh: true));
        }

        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(bloc.state, isA<TrainerLoaded>());
        final loadedState = bloc.state as TrainerLoaded;
        expect(loadedState.allTrainers.length, 2);

        await bloc.close();
      },
    );
  });

  group('6. TrainerProfile Initials & Avatar Edge Cases', () {
    test('initials handles null, empty, whitespace and multi-word names', () {
      const p1 = TrainerProfile(id: '1', userId: 'u1', hourlyRate: 100);
      expect(p1.initials, 'TR');

      const p2 = TrainerProfile(
        id: '2',
        userId: 'u2',
        hourlyRate: 100,
        displayName: '',
      );
      expect(p2.initials, 'TR');

      const p3 = TrainerProfile(
        id: '3',
        userId: 'u3',
        hourlyRate: 100,
        displayName: '   ',
      );
      expect(p3.initials, 'TR');

      const p4 = TrainerProfile(
        id: '4',
        userId: 'u4',
        hourlyRate: 100,
        displayName: 'Bob',
      );
      expect(p4.initials, 'BO');

      const p5 = TrainerProfile(
        id: '5',
        userId: 'u5',
        hourlyRate: 100,
        displayName: 'A',
      );
      expect(p5.initials, 'A');

      const p6 = TrainerProfile(
        id: '6',
        userId: 'u6',
        hourlyRate: 100,
        displayName: 'John Michael Doe',
      );
      expect(p6.initials, 'JM');
    });

    test('initials with surrogate pair (emoji prefix) does not crash', () {
      // Emojis like 🏋️ are multi-byte surrogate pairs in UTF-16
      const emojiTrainer = TrainerProfile(
        id: 'e1',
        userId: 'ue1',
        hourlyRate: 100,
        displayName: '🏋️ Coach Mike',
      );

      // Verify whether calling initials throws or returns without unhandled exception
      expect(() => emojiTrainer.initials, returnsNormally);
      final init = emojiTrainer.initials;
      expect(init.isNotEmpty, isTrue);
    });
  });

  group('7. Fee Math Split Precision & Discrepancy Stress Tests', () {
    test(
      'enforces fee + payout == hourlyRate exactly (15.05) with 0-cent discrepancy',
      () {
        const profile = TrainerProfile(
          id: 'test-disc',
          userId: 'u',
          hourlyRate: 15.05,
          platformFeePct: 10.0,
        );

        final fee = profile.platformFeeAmountPerHour;
        final payout = profile.trainerPayoutPerHour;
        final sum = double.parse((fee + payout).toStringAsFixed(2));

        expect(fee, equals(1.51));
        expect(payout, equals(13.54));
        expect(
          sum,
          equals(15.05),
          reason:
              'Rate 15.05: fee (1.51) + payout (13.54) = 15.05, exactly matching hourlyRate.',
        );
      },
    );

    test('demonstrates client and backend payout parity at rate 15.05', () {
      const profile = TrainerProfile(
        id: 'p-div',
        userId: 'u',
        hourlyRate: 15.05,
        platformFeePct: 10.0,
      );

      expect(profile.trainerPayoutPerHour, equals(13.54));
      expect(profile.platformFeeAmountPerHour, equals(1.51));
      expect(
        double.parse(
          (profile.trainerPayoutPerHour + profile.platformFeeAmountPerHour)
              .toStringAsFixed(2),
        ),
        equals(15.05),
      );
    });
  });

  group('8. TrainerDiscoveryScreen Empty Catalog State Tests', () {
    testWidgets(
      'Empty database catalog renders EmptyStateWidget with Become a Coach button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TrainerDiscoveryScreen(
              trainerService: EmptyMockTrainerService(),
            ),
          ),
        );

        // Await future resolution and animation frame
        await tester.pumpAndSettle();

        // EmptyMockTrainerService returned [] (empty catalog)
        // Verify that Marcus Vance (hardcoded fallback) is NOT present:
        expect(
          find.text('Marcus Vance'),
          findsNothing,
          reason:
              'Mock trainers must not conceal empty database catalog.',
        );
        // Verify EmptyStateWidget IS displayed:
        expect(
          find.byType(EmptyStateWidget),
          findsOneWidget,
          reason:
              'EmptyStateWidget is rendered when catalog is empty.',
        );
        expect(find.text('No Coaches Registered Yet'), findsOneWidget);
        expect(find.text('Become a Coach'), findsOneWidget);
      },
    );
  });

  group('9. State Machine Filter Preservation on Profile Operations', () {
    test(
      'RegisterTrainer preserves active filter criteria when reloading catalog',
      () async {
        final bloc = TrainerBloc();
        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 60));

        // User has an active filter
        bloc.add(
          const FilterTrainers(
            TrainerFilterCriteria(selectedSpecialty: 'Strength'),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final stateWithFilter = bloc.state as TrainerLoaded;
        expect(stateWithFilter.currentFilter.selectedSpecialty, 'Strength');

        // User completes registration
        bloc.add(
          const RegisterTrainer(
            bio: 'New coach bio',
            certifications: <String>['NASM'],
            specialties: <String>['Strength'],
            experienceYears: 5,
            hourlyRate: 1200,
          ),
        );

        // Wait for registration and subsequent LoadTrainers reload
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(bloc.state, isA<TrainerLoaded>());
        final finalState = bloc.state as TrainerLoaded;

        // Verify filter is preserved
        expect(
          finalState.currentFilter.selectedSpecialty,
          equals('Strength'),
          reason:
              'Active filter criteria is preserved across profile registration reload.',
        );

        await bloc.close();
      },
    );
  });
}
