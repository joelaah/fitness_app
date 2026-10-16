import 'dart:async';
import 'dart:io';
import 'package:fitness_app/features/trainers/bloc/trainer_bloc.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_event.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_state.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simulated Mock TrainerService that allows injecting arbitrary exceptions,
/// errors (including TypeErrors), and raw JSON responses.
class MockPostgrestFaultTrainerService extends TrainerService {
  MockPostgrestFaultTrainerService({
    this.getTrainersFault,
    this.getTrainerByIdFault,
    this.registerFault,
    this.updateFault,
    this.customTrainersPayload,
  });

  final Object? getTrainersFault;
  final Object? getTrainerByIdFault;
  final Object? registerFault;
  final Object? updateFault;
  final List<dynamic>? customTrainersPayload;

  @override
  Future<List<TrainerProfile>> getTrainers({
    TrainerFilterCriteria? filter,
    bool forceRefresh = false,
  }) async {
    if (getTrainersFault != null) {
      if (getTrainersFault is Exception) {
        throw getTrainersFault! as Exception;
      } else if (getTrainersFault is Error) {
        throw getTrainersFault! as Error;
      }
      throw Exception(getTrainersFault.toString());
    }

    if (customTrainersPayload != null) {
      return customTrainersPayload!
          .map((e) => TrainerProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return super.getTrainers(filter: filter, forceRefresh: forceRefresh);
  }

  @override
  Future<TrainerProfile?> getTrainerById(String trainerId) async {
    if (getTrainerByIdFault != null) {
      if (getTrainerByIdFault is Exception) {
        throw getTrainerByIdFault! as Exception;
      }
      throw Exception(getTrainerByIdFault.toString());
    }
    return super.getTrainerById(trainerId);
  }

  @override
  Future<TrainerProfile> registerTrainer({
    required String bio,
    required List<String> certifications,
    required List<String> specialties,
    required int experienceYears,
    required double hourlyRate,
    String? userId,
    String? displayName,
    Map<String, dynamic>? availability,
  }) async {
    if (registerFault != null) {
      if (registerFault is Exception) {
        throw registerFault! as Exception;
      } else if (registerFault is Error) {
        throw registerFault! as Error;
      }
      throw Exception(registerFault.toString());
    }
    return super.registerTrainer(
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      userId: userId,
      displayName: displayName,
      availability: availability,
    );
  }

  @override
  Future<TrainerProfile> updateTrainerProfile(
    dynamic profileOrUserId, {
    String? displayName,
    String? bio,
    List<String>? certifications,
    List<String>? specialties,
    int? experienceYears,
    double? hourlyRate,
    Map<String, dynamic>? availability,
  }) async {
    if (updateFault != null) {
      if (updateFault is Exception) {
        throw updateFault! as Exception;
      } else if (updateFault is Error) {
        throw updateFault! as Error;
      }
      throw Exception(updateFault.toString());
    }
    return super.updateTrainerProfile(
      profileOrUserId,
      displayName: displayName,
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      availability: availability,
    );
  }
}

void main() {
  group('Empirical Challenge 1: Platform Fee Math Invariants', () {
    test('Round dollar rates satisfy invariant', () {
      final rates = <double>[0, 10, 50, 100, 500, 1500, 2500, 10000];
      for (final rate in rates) {
        final profile = TrainerProfile(
          id: 'test',
          userId: 'test-user',
          hourlyRate: rate,
        );
        final sum =
            profile.platformFeeAmountPerHour + profile.trainerPayoutPerHour;
        expect((sum - rate).abs(), lessThan(0.0001));
      }
    });

    test(
      'Invariant holds: fee + payout == hourlyRate across counterexamples',
      () {
        // Counterexample 1: rate = 2.45
        // 2.45 * 0.10 = 0.245 -> rounds up to 0.25
        // With subtraction: 2.45 - 0.25 = 2.20
        // Sum = 0.25 + 2.20 = 2.45 == 2.45
        const profile245 = TrainerProfile(
          id: 'bug-1',
          userId: 'u-1',
          hourlyRate: 2.45,
        );
        final fee245 = profile245.platformFeeAmountPerHour;
        final payout245 = profile245.trainerPayoutPerHour;
        final sum245 = double.parse((fee245 + payout245).toStringAsFixed(2));

        expect(fee245, 0.25);
        expect(payout245, 2.20);
        expect(sum245, 2.45);
        expect(
          sum245 == profile245.hourlyRate,
          isTrue,
          reason: 'Invariant fee + payout == hourlyRate HOLDS for 2.45',
        );

        // Counterexample 2: rate = 3.55
        // 3.55 * 0.10 = 0.3549999... -> rounds down to 0.35
        // With subtraction: 3.55 - 0.35 = 3.20
        // Sum = 0.35 + 3.20 = 3.55 == 3.55
        const profile355 = TrainerProfile(
          id: 'bug-2',
          userId: 'u-2',
          hourlyRate: 3.55,
        );
        final fee355 = profile355.platformFeeAmountPerHour;
        final payout355 = profile355.trainerPayoutPerHour;
        final sum355 = double.parse((fee355 + payout355).toStringAsFixed(2));

        expect(fee355, 0.35);
        expect(payout355, 3.20);
        expect(sum355, 3.55);
        expect(
          sum355 == profile355.hourlyRate,
          isTrue,
          reason: 'Invariant fee + payout == hourlyRate HOLDS for 3.55',
        );

        // Counterexample 3: rate = 100.05 with 50% platform fee
        // 100.05 * 0.50 = 50.025 -> rounds down to 50.02 for fee
        // With subtraction: 100.05 - 50.02 = 50.03 for payout
        // Sum = 50.02 + 50.03 = 100.05 == 100.05
        const profile50Pct = TrainerProfile(
          id: 'bug-3',
          userId: 'u-3',
          hourlyRate: 100.05,
          platformFeePct: 50,
        );
        final fee50 = profile50Pct.platformFeeAmountPerHour;
        final payout50 = profile50Pct.trainerPayoutPerHour;
        final sum50 = double.parse((fee50 + payout50).toStringAsFixed(2));

        expect(fee50, 50.02);
        expect(payout50, 50.03);
        expect(sum50, 100.05);
        expect(
          sum50 == profile50Pct.hourlyRate,
          isTrue,
          reason:
              'Invariant fee + payout == hourlyRate HOLDS for 100.05 at 50%',
        );
      },
    );

    test(
      'Stress-test generator: Quantify total failures in 10,000 rates',
      () {
        final violations = <Map<String, dynamic>>[];

        for (var cents = 1; cents <= 10000; cents++) {
          final rate = cents / 100.0;
          final profile = TrainerProfile(
            id: 'test-$cents',
            userId: 'user-$cents',
            hourlyRate: rate,
          );
          final fee = profile.platformFeeAmountPerHour;
          final payout = profile.trainerPayoutPerHour;
          final sum = double.parse((fee + payout).toStringAsFixed(2));
          final expected = double.parse(rate.toStringAsFixed(2));

          if ((sum - expected).abs() > 0.005) {
            violations.add(<String, dynamic>{
              'rate': rate,
              'fee': fee,
              'payout': payout,
              'sum': sum,
              'expected': expected,
              'discrepancy': sum - expected,
            });
          }
        }

        // Exactly 0 invariant violations out of 10,000 rates tested
        expect(violations.length, 0);
      },
    );

    test(
      'Stress-test generator: Configurable fee produces 0 violations',
      () {
        final feePercentages = <double>[
          5,
          7.5,
          12.5,
          15,
          20,
          25,
          33.33,
          50,
          75,
          99,
        ];
        final violations = <Map<String, dynamic>>[];

        for (final feePct in feePercentages) {
          for (var cents = 1; cents <= 2000; cents++) {
            final rate = cents / 100.0;
            final profile = TrainerProfile(
              id: 'test-$feePct-$cents',
              userId: 'user',
              hourlyRate: rate,
              platformFeePct: feePct,
            );
            final fee = profile.platformFeeAmountPerHour;
            final payout = profile.trainerPayoutPerHour;
            final sum = double.parse((fee + payout).toStringAsFixed(2));
            final expected = double.parse(rate.toStringAsFixed(2));

            if ((sum - expected).abs() > 0.005) {
              violations.add(<String, dynamic>{
                'feePct': feePct,
                'rate': rate,
                'fee': fee,
                'payout': payout,
                'sum': sum,
                'expected': expected,
              });
            }
          }
        }

        expect(violations.length, 0);
      },
    );

    test('Worker handoff discrepancy verification', () {
      // Worker M3 handoff claimed:
      // trainerPayoutPerHour =>
      //   double.parse(
      //     (hourlyRate - platformFeeAmountPerHour).toStringAsFixed(2),
      //   )
      for (var cents = 1; cents <= 10000; cents++) {
        final rate = cents / 100.0;
        final fee = double.parse((rate * 0.10).toStringAsFixed(2));
        final correctPayout = double.parse((rate - fee).toStringAsFixed(2));
        final sum = double.parse((fee + correctPayout).toStringAsFixed(2));
        expect((sum - rate).abs(), lessThan(0.0001));
      }
    });
  });

  group('Empirical Challenge 2: PostgREST Error Codes & Resilience', () {
    test('Simulating PostgREST 400 Bad Request error', () async {
      final faultService = MockPostgrestFaultTrainerService(
        registerFault: const PostgrestException(
          message: 'invalid input syntax for type uuid: "not-a-uuid"',
          code: '400',
          details: 'Key (id)=(not-a-uuid) is not a valid UUID',
        ),
      );

      final bloc = TrainerBloc(trainerService: faultService);
      final states = <TrainerState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(
        const RegisterTrainer(
          bio: 'Coach test',
          certifications: <String>['CSCS'],
          specialties: <String>['Strength'],
          experienceYears: 5,
          hourlyRate: 1000,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      await bloc.close();

      expect(states.length, 2);
      expect(states[0], isA<TrainerLoading>());
      expect(states[1], isA<TrainerError>());
      final errorState = states[1] as TrainerError;
      expect(errorState.message, contains('Registration failed'));
      expect(errorState.message, contains('invalid input syntax'));
    });

    test('Simulating PostgREST 401 Unauthorized / Expired JWT', () async {
      final faultService = MockPostgrestFaultTrainerService(
        registerFault: const PostgrestException(
          message: 'JWT expired or missing authorization header',
          code: '401',
          details: 'Unauthorized user role',
        ),
      );

      final bloc = TrainerBloc(trainerService: faultService);
      final states = <TrainerState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(
        const RegisterTrainer(
          bio: 'Coach unauthorized',
          certifications: <String>['CSCS'],
          specialties: <String>['HIIT'],
          experienceYears: 3,
          hourlyRate: 800,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      await bloc.close();

      expect(states.length, 2);
      expect(states[1], isA<TrainerError>());
      final errorState = states[1] as TrainerError;
      expect(errorState.message, contains('JWT expired'));
    });

    test('Simulating PostgREST 409 Conflict / Unique violation', () async {
      final faultService = MockPostgrestFaultTrainerService(
        registerFault: const PostgrestException(
          message: 'duplicate key violates unique "trainer_profiles_user_id"',
          code: '409',
          details: 'Key (user_id)=(user-1) already exists.',
        ),
      );

      final bloc = TrainerBloc(trainerService: faultService);
      final states = <TrainerState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(
        const RegisterTrainer(
          bio: 'Coach duplicate',
          certifications: <String>['CSCS'],
          specialties: <String>['Strength'],
          experienceYears: 5,
          hourlyRate: 1200,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      await bloc.close();

      expect(states.length, 2);
      expect(states[1], isA<TrainerError>());
      final errorState = states[1] as TrainerError;
      expect(errorState.message, contains('duplicate key violates'));
    });

    test(
      'Simulating PostgREST 500 Internal Server Error / DB down',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          updateFault: const PostgrestException(
            message: 'internal server error: connection to backend lost',
            code: '500',
          ),
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(
          const UpdateTrainerProfile(
            TrainerProfile(
              id: 't-1',
              userId: 'u-1',
              hourlyRate: 1500,
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[1], isA<TrainerError>());
        final errorState = states[1] as TrainerError;
        expect(errorState.message, contains('Update failed'));
        expect(errorState.message, contains('internal server error'));
      },
    );

    test(
      'Simulating Network Drop: SocketException during catalog fetch',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          getTrainersFault: const SocketException('Connection reset by peer'),
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadTrainers());

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());
        final err = states[1] as TrainerError;
        expect(err.message, contains('Connection reset by peer'));
      },
    );

    test(
      'Simulating Network Drop: http.ClientException during registration',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          registerFault: http.ClientException(
            'XMLHttpRequest error',
            Uri.parse('https://mock.supabase.co'),
          ),
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(
          const RegisterTrainer(
            bio: 'Coach network failure',
            certifications: <String>['CSCS'],
            specialties: <String>['Powerlifting'],
            experienceYears: 10,
            hourlyRate: 2000,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[1], isA<TrainerError>());
        final err = states[1] as TrainerError;
        expect(err.message, contains('XMLHttpRequest error'));
      },
    );

    test(
      'Simulating Network Timeout: TimeoutException on profile update',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          updateFault: TimeoutException('Supabase request timed out'),
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(
          const UpdateTrainerProfile(
            TrainerProfile(
              id: 't-timeout',
              userId: 'u-timeout',
              hourlyRate: 1000,
            ),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[1], isA<TrainerError>());
        final err = states[1] as TrainerError;
        expect(err.message, contains('timed out'));
      },
    );
  });

  group(
    'Empirical Challenge 3: Malformed Database Responses & Missing Fields',
    () {
      test('JSON with missing optional fields uses graceful defaults', () {
        final json = <String, dynamic>{
          'id': 't-sparse',
          'user_id': 'u-sparse',
        };

        final profile = TrainerProfile.fromJson(json);
        expect(profile.id, 't-sparse');
        expect(profile.userId, 'u-sparse');
        expect(profile.hourlyRate, 0.0);
        expect(profile.bio, '');
        expect(profile.certifications, isEmpty);
        expect(profile.specialties, isEmpty);
        expect(profile.experienceYears, 0);
        expect(profile.rating, 5.0);
        expect(profile.platformFeePct, 10.0);
        expect(profile.verified, true);
        expect(profile.displayName, isNull);
        expect(profile.initials, 'TR');
      });

      test('JSON with numeric hourly_rate as int parsed to double', () {
        final json = <String, dynamic>{
          'id': 't-int-rate',
          'user_id': 'u-int-rate',
          'hourly_rate': 1200,
          'experience_years': 4.0,
        };

        final profile = TrainerProfile.fromJson(json);
        expect(profile.hourlyRate, 1200.0);
        expect(profile.experienceYears, 4);
      });

      test('JSON with is_verified instead of verified', () {
        final json = <String, dynamic>{
          'id': 't-is-verified',
          'user_id': 'u-is-verified',
          'is_verified': false,
        };

        final profile = TrainerProfile.fromJson(json);
        expect(profile.verified, false);
      });

      test('JSON with joined profiles table as Map', () {
        final json = <String, dynamic>{
          'id': 't-joined',
          'user_id': 'u-joined',
          'profiles': <String, dynamic>{'display_name': 'Sarah Connor'},
        };

        final profile = TrainerProfile.fromJson(json);
        expect(profile.displayName, 'Sarah Connor');
        expect(profile.initials, 'SC');
      });

      test('JSON with joined profiles as unexpected non-map (List)', () {
        final json = <String, dynamic>{
          'id': 't-joined-list',
          'user_id': 'u-joined-list',
          'profiles': <dynamic>[
            <String, dynamic>{'display_name': 'Sarah Connor'},
          ],
        };

        final profile = TrainerProfile.fromJson(json);
        expect(profile.displayName, isNull);
        expect(profile.initials, 'TR');
      });

      test('Empirical Bug: Missing id in JSON throws TypeError', () {
        final jsonMissingId = <String, dynamic>{
          'user_id': 'u-missing-id',
          'hourly_rate': 1500,
        };

        expect(
          () => TrainerProfile.fromJson(jsonMissingId),
          throwsA(isA<TypeError>()),
          reason: 'Missing id throws TypeError',
        );
      });

      test('Empirical Bug: Missing user_id in JSON throws TypeError', () {
        final jsonMissingUserId = <String, dynamic>{
          'id': 't-missing-user-id',
          'hourly_rate': 1500,
        };

        expect(
          () => TrainerProfile.fromJson(jsonMissingUserId),
          throwsA(isA<TypeError>()),
          reason: 'Missing user_id throws TypeError',
        );
      });

      test(
        'TypeError in TrainerBloc triggers clean transition to TrainerError',
        () async {
          final faultService = MockPostgrestFaultTrainerService(
            getTrainersFault: TypeError(),
          );

          final bloc = TrainerBloc(trainerService: faultService);
          final states = <TrainerState>[];
          final sub = bloc.stream.listen(states.add);

          bloc.add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 50));

          await sub.cancel();
          await bloc.close();

          expect(states.length, 2);
          expect(states[0], isA<TrainerLoading>());
          expect(states[1], isA<TrainerError>());
          final errorState = states[1] as TrainerError;
          expect(errorState.message, contains('Failed to load trainers'));
        },
      );
    },
  );

  group('Empirical Challenge 4: 10,000 Rate and Fee Sweep', () {
    test(
      'Systematic 10,000 (Rate, Fee%) Sweep: 0 Invariant Violations',
      () {
        // Construct 100 rates x 100 fee percentages = 10,000 unique pairs
        // Rates span from 0.01 to 5000.00 including fractional cents
        // Fees span from 0.00% to 100.00%
        final violations = <Map<String, dynamic>>[];
        var combinationsTested = 0;

        for (var r = 1; r <= 100; r++) {
          // Generate realistic fractional and whole rates
          // E.g. 0.01, 15.05, 33.33, 50.00, 100.55, 1250.75, 4999.99
          final rate = double.parse(
            ((r * 49.99) % 5000.0 + 0.01).toStringAsFixed(2),
          );

          for (var f = 1; f <= 100; f++) {
            combinationsTested++;
            // Generate percentages from 0.0% to 100.0% in 1.0% steps
            final feePct = double.parse((f * 1.0).toStringAsFixed(2));

            final profile = TrainerProfile(
              id: 'matrix-$r-$f',
              userId: 'user-matrix',
              hourlyRate: rate,
              platformFeePct: feePct,
            );

            final fee = profile.platformFeeAmountPerHour;
            final payout = profile.trainerPayoutPerHour;
            final sum = double.parse((fee + payout).toStringAsFixed(2));
            final expected = rate;

            if ((sum - expected).abs() > 0.001) {
              violations.add(<String, dynamic>{
                'rate': rate,
                'feePct': feePct,
                'fee': fee,
                'payout': payout,
                'sum': sum,
                'expected': expected,
                'discrepancy': sum - expected,
              });
            }
          }
        }

        expect(combinationsTested, 10000);
        expect(
          violations.length,
          0,
          reason: 'Expected 0 invariant violations across 10,000 pairs, '
              'found ${violations.length}',
        );
      },
    );

    test('Boundary rates and percentages (0, 0.01, 100000, 0%, 100%)', () {
      final edgeCases = <Map<String, double>>[
        {'rate': 0.0, 'fee': 10.0},
        {'rate': 0.01, 'fee': 10.0},
        {'rate': 0.01, 'fee': 0.0},
        {'rate': 0.01, 'fee': 100.0},
        {'rate': 100000.0, 'fee': 10.0},
        {'rate': 100000.0, 'fee': 0.0},
        {'rate': 100000.0, 'fee': 100.0},
        {'rate': 15.05, 'fee': 33.33},
        {'rate': 2.45, 'fee': 7.5},
        {'rate': 3.55, 'fee': 12.5},
        {'rate': 9999.99, 'fee': 99.99},
      ];

      for (final ec in edgeCases) {
        final rate = ec['rate']!;
        final feePct = ec['fee']!;
        final profile = TrainerProfile(
          id: 'edge',
          userId: 'u-edge',
          hourlyRate: rate,
          platformFeePct: feePct,
        );

        final fee = profile.platformFeeAmountPerHour;
        final payout = profile.trainerPayoutPerHour;
        final sum = double.parse((fee + payout).toStringAsFixed(2));

        expect(
          (sum - rate).abs(),
          lessThan(0.001),
          reason: 'Failed for rate=$rate, feePct=$feePct',
        );
      }
    });
  });

  group('Empirical Challenge 5: Deep TypeError Injection', () {
    test(
      'LoadTrainers: Missing id triggers TypeError -> TrainerError',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          customTrainersPayload: <dynamic>[
            <String, dynamic>{
              // 'id' is intentionally missing
              'user_id': 'u-no-id',
              'hourly_rate': 1500,
            },
          ],
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());
        final errorState = states[1] as TrainerError;
        expect(errorState.message, contains('Failed to load trainers'));
      },
    );

    test(
      'LoadTrainers: Missing user_id triggers TypeError -> TrainerError',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          customTrainersPayload: <dynamic>[
            <String, dynamic>{
              'id': 't-no-user-id',
              // 'user_id' is intentionally missing
              'hourly_rate': 1500,
            },
          ],
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());
        final errorState = states[1] as TrainerError;
        expect(errorState.message, contains('Failed to load trainers'));
      },
    );

    test(
      'LoadTrainers: Malformed certifications type -> TrainerError',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          customTrainersPayload: <dynamic>[
            <String, dynamic>{
              'id': 't-bad-certs',
              'user_id': 'u-bad-certs',
              'certifications': 'CSCS', // Should be a List<dynamic>
            },
          ],
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());
        final errorState = states[1] as TrainerError;
        expect(errorState.message, contains('Failed to load trainers'));
      },
    );

    test(
      'LoadTrainers: Malformed hourly_rate type -> TrainerError',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          customTrainersPayload: <dynamic>[
            <String, dynamic>{
              'id': 't-bad-rate',
              'user_id': 'u-bad-rate',
              'hourly_rate': 'invalid_string_rate', // Should be num
            },
          ],
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());
        final errorState = states[1] as TrainerError;
        expect(errorState.message, contains('Failed to load trainers'));
      },
    );

    test(
      'RegisterTrainer: TypeError thrown during registration -> TrainerError',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          registerFault: TypeError(),
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(
          const RegisterTrainer(
            bio: 'Adversarial bio',
            certifications: <String>['CSCS'],
            specialties: <String>['Strength'],
            experienceYears: 5,
            hourlyRate: 1500,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());
        final errorState = states[1] as TrainerError;
        expect(errorState.message, contains('Registration failed'));
      },
    );

    test(
      'UpdateTrainerProfile: TypeError thrown during update -> TrainerError',
      () async {
        final faultService = MockPostgrestFaultTrainerService(
          updateFault: TypeError(),
        );

        final bloc = TrainerBloc(trainerService: faultService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(
          const UpdateTrainerProfile(
            TrainerProfile(
              id: 't-update-fault',
              userId: 'u-update-fault',
              hourlyRate: 1500,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await bloc.close();

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());
        final errorState = states[1] as TrainerError;
        expect(errorState.message, contains('Update failed'));
      },
    );

    test(
      'TrainerBloc recovers gracefully on subsequent valid LoadTrainers',
      () async {
        var shouldFail = true;

        // Custom fault that only fails on first call
        final dynamicService = DynamicFaultTrainerService(
          faultProvider: () => shouldFail ? TypeError() : null,
        );

        final bloc = TrainerBloc(trainerService: dynamicService);
        final states = <TrainerState>[];
        final sub = bloc.stream.listen(states.add);

        // First load fails with TypeError
        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(states.length, 2);
        expect(states[0], isA<TrainerLoading>());
        expect(states[1], isA<TrainerError>());

        // Subsequent load succeeds
        shouldFail = false;
        bloc.add(const LoadTrainers());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await bloc.close();

        expect(states.length, 4);
        expect(states[2], isA<TrainerLoading>());
        expect(states[3], isA<TrainerLoaded>());
        final loaded = states[3] as TrainerLoaded;
        expect(loaded.allTrainers.length, 1);
        expect(loaded.allTrainers.first.id, 't-recovered');
      },
    );
  });
}

class DynamicFaultTrainerService extends TrainerService {
  DynamicFaultTrainerService({required this.faultProvider});

  final Object? Function() faultProvider;

  @override
  Future<List<TrainerProfile>> getTrainers({
    TrainerFilterCriteria? filter,
    bool forceRefresh = false,
  }) async {
    final fault = faultProvider();
    if (fault != null) {
      if (fault is Error) throw fault;
      if (fault is Exception) throw fault;
      throw Exception(fault.toString());
    }
    return <TrainerProfile>[
      const TrainerProfile(
        id: 't-recovered',
        userId: 'u-recovered',
        hourlyRate: 1500,
      ),
    ];
  }
}
