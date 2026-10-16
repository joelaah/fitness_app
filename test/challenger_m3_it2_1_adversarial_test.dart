import 'dart:math';
import 'package:fitness_app/features/trainers/bloc/trainer_bloc.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_event.dart';
import 'package:fitness_app/features/trainers/bloc/trainer_state.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configurable mock service allowing injection of delays and arbitrary
/// faults (Exception or Error, such as TypeError) into each operation.
class ConfigurableMockTrainerService extends TrainerService {
  ConfigurableMockTrainerService({
    this.getTrainersDelay = Duration.zero,
    this.registerDelay = Duration.zero,
    this.updateDelay = Duration.zero,
    this.getMyProfileDelay = Duration.zero,
    this.getTrainersFault,
    this.registerFault,
    this.updateFault,
    this.getMyProfileFault,
    List<TrainerProfile>? catalog,
  }) : _catalog = catalog != null
            ? List<TrainerProfile>.from(catalog)
            : <TrainerProfile>[
                const TrainerProfile(
                  id: 'coach-1',
                  userId: 'user-coach-1',
                  displayName: 'Coach Alpha',
                  bio: 'Strength & Conditioning Specialist',
                  specialties: <String>['Strength', 'Powerlifting'],
                  experienceYears: 6,
                  hourlyRate: 1500,
                  rating: 4.9,
                ),
                const TrainerProfile(
                  id: 'coach-2',
                  userId: 'user-coach-2',
                  displayName: 'Coach Beta',
                  bio: 'Yoga and Mobility Expert',
                  specialties: <String>['Yoga', 'Mobility'],
                  experienceYears: 4,
                  hourlyRate: 800,
                  rating: 4.8,
                ),
                const TrainerProfile(
                  id: 'coach-3',
                  userId: 'user-coach-3',
                  displayName: 'Coach Gamma',
                  bio: 'HIIT and Fat Loss Coach',
                  specialties: <String>['HIIT', 'Strength'],
                  experienceYears: 5,
                  hourlyRate: 1200,
                  rating: 4.7,
                ),
              ];

  final Duration getTrainersDelay;
  final Duration registerDelay;
  final Duration updateDelay;
  final Duration getMyProfileDelay;

  final Object? getTrainersFault;
  final Object? registerFault;
  final Object? updateFault;
  final Object? getMyProfileFault;

  final List<TrainerProfile> _catalog;

  List<TrainerProfile> get currentCatalog => List.unmodifiable(_catalog);

  @override
  Future<List<TrainerProfile>> getTrainers({
    TrainerFilterCriteria? filter,
    bool forceRefresh = false,
  }) async {
    if (getTrainersDelay > Duration.zero) {
      await Future<void>.delayed(getTrainersDelay);
    }
    if (getTrainersFault != null) {
      if (getTrainersFault is Exception) {
        throw getTrainersFault! as Exception;
      } else if (getTrainersFault is Error) {
        throw getTrainersFault! as Error;
      }
      throw Exception(getTrainersFault.toString());
    }
    return List<TrainerProfile>.from(_catalog);
  }

  @override
  Future<TrainerProfile?> getMyTrainerProfile() async {
    if (getMyProfileDelay > Duration.zero) {
      await Future<void>.delayed(getMyProfileDelay);
    }
    if (getMyProfileFault != null) {
      if (getMyProfileFault is Exception) {
        throw getMyProfileFault! as Exception;
      } else if (getMyProfileFault is Error) {
        throw getMyProfileFault! as Error;
      }
      throw Exception(getMyProfileFault.toString());
    }
    return _catalog.isNotEmpty ? _catalog.first : null;
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
    if (registerDelay > Duration.zero) {
      await Future<void>.delayed(registerDelay);
    }
    if (registerFault != null) {
      if (registerFault is Exception) {
        throw registerFault! as Exception;
      } else if (registerFault is Error) {
        throw registerFault! as Error;
      }
      throw Exception(registerFault.toString());
    }
    final newProfile = TrainerProfile(
      id: 'coach-new-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId ?? 'user-new',
      displayName: displayName ?? 'New Coach',
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
      availability: availability ?? const {},
    );
    _catalog.add(newProfile);
    return newProfile;
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
    if (updateDelay > Duration.zero) {
      await Future<void>.delayed(updateDelay);
    }
    if (updateFault != null) {
      if (updateFault is Exception) {
        throw updateFault! as Exception;
      } else if (updateFault is Error) {
        throw updateFault! as Error;
      }
      throw Exception(updateFault.toString());
    }
    if (profileOrUserId is TrainerProfile) {
      final index = _catalog.indexWhere((p) => p.id == profileOrUserId.id);
      if (index != -1) {
        _catalog[index] = profileOrUserId;
      }
      return profileOrUserId;
    }
    final updated = TrainerProfile(
      id: 'coach-updated',
      userId: profileOrUserId.toString(),
      displayName: displayName ?? 'Updated Coach',
      bio: bio ?? '',
      certifications: certifications ?? const [],
      specialties: specialties ?? const [],
      experienceYears: experienceYears ?? 0,
      hourlyRate: hourlyRate ?? 1000,
      availability: availability ?? const {},
    );
    return updated;
  }
}

void main() {
  group(
    'Empirical Challenge 1: In-Flight Filter Preservation',
    () {
      test(
        'FilterTrainers during in-flight LoadTrainers preserves criteria',
        () async {
          final service = ConfigurableMockTrainerService(
            getTrainersDelay: const Duration(milliseconds: 70),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(bloc.state, isA<TrainerLoading>());

          const yogaFilter = TrainerFilterCriteria(selectedSpecialty: 'Yoga');
          bloc.add(const FilterTrainers(yogaFilter));

          await Future<void>.delayed(const Duration(milliseconds: 100));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.currentFilter.selectedSpecialty, equals('Yoga'));
          expect(loaded.filteredTrainers.length, equals(1));
          expect(
            loaded.filteredTrainers.first.displayName,
            equals('Coach Beta'),
          );
          expect(bloc.activeFilter.selectedSpecialty, equals('Yoga'));

          await bloc.close();
        },
      );

      test(
        'Rapid successive filters during LoadTrainers preserves latest',
        () async {
          final service = ConfigurableMockTrainerService(
            getTrainersDelay: const Duration(milliseconds: 100),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 15));
          expect(bloc.state, isA<TrainerLoading>());

          bloc.add(
            const FilterTrainers(
              TrainerFilterCriteria(selectedSpecialty: 'Yoga'),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          bloc.add(
            const FilterTrainers(
              TrainerFilterCriteria(selectedSpecialty: 'HIIT'),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          bloc.add(
            const FilterTrainers(
              TrainerFilterCriteria(
                selectedSpecialty: 'Strength',
                maxHourlyRate: 1400,
              ),
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 120));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.currentFilter.selectedSpecialty, equals('Strength'));
          expect(loaded.currentFilter.maxHourlyRate, equals(1400));
          expect(loaded.filteredTrainers.length, equals(1));
          expect(
            loaded.filteredTrainers.first.displayName,
            equals('Coach Gamma'),
          );

          await bloc.close();
        },
      );

      test(
        'ResetTrainerFilter during in-flight LoadTrainers resets criteria',
        () async {
          final service = ConfigurableMockTrainerService(
            getTrainersDelay: const Duration(milliseconds: 80),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 15));

          bloc.add(
            const FilterTrainers(
              TrainerFilterCriteria(selectedSpecialty: 'Yoga'),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          bloc.add(const ResetTrainerFilter());

          await Future<void>.delayed(const Duration(milliseconds: 120));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.currentFilter.isEmpty, isTrue);
          expect(loaded.filteredTrainers.length, equals(3));
          expect(loaded.allTrainers.length, equals(3));

          await bloc.close();
        },
      );

      test(
        'SelectTrainer and deselect during LoadTrainers retains null',
        () async {
          final service = ConfigurableMockTrainerService(
            getTrainersDelay: const Duration(milliseconds: 80),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final coach = service.currentCatalog.first;
          bloc.add(SelectTrainer(coach));
          await Future<void>.delayed(const Duration(milliseconds: 10));
          bloc.add(const SelectTrainer(null));

          await Future<void>.delayed(const Duration(milliseconds: 100));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.selectedTrainer, isNull);

          await bloc.close();
        },
      );
    },
  );

  group(
    'Empirical Challenge 2: Filter Preservation Across Profile Operations',
    () {
      test(
        'RegisterTrainer preserves active filter across catalog reload',
        () async {
          final service = ConfigurableMockTrainerService();
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(bloc.state, isA<TrainerLoaded>());

          const filter = TrainerFilterCriteria(
            selectedSpecialty: 'Strength',
            maxHourlyRate: 1600,
          );
          bloc.add(const FilterTrainers(filter));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          bloc.add(
            const RegisterTrainer(
              bio: 'Strength specialist and lifter',
              certifications: <String>['CSCS'],
              specialties: <String>['Strength'],
              experienceYears: 3,
              hourlyRate: 1300,
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 120));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.currentFilter, equals(filter));
          expect(loaded.allTrainers.length, equals(4));
          expect(loaded.filteredTrainers.length, equals(3));
          expect(
            loaded.filteredTrainers.any(
              (t) => t.bio.contains('Strength specialist'),
            ),
            isTrue,
          );

          await bloc.close();
        },
      );

      test(
        'UpdateTrainerProfile preserves active filter criteria and reapplies',
        () async {
          final service = ConfigurableMockTrainerService();
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 50));

          const filter = TrainerFilterCriteria(selectedSpecialty: 'Yoga');
          bloc.add(const FilterTrainers(filter));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final coachBeta = service.currentCatalog[1];
          final updatedCoachBeta = coachBeta.copyWith(
            bio: 'Updated Yoga Guru and Kundalini Specialist',
            hourlyRate: 950,
          );

          bloc.add(UpdateTrainerProfile(updatedCoachBeta));
          await Future<void>.delayed(const Duration(milliseconds: 120));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.currentFilter, equals(filter));
          expect(loaded.filteredTrainers.length, equals(1));
          expect(
            loaded.filteredTrainers.first.bio,
            contains('Updated Yoga Guru'),
          );
          expect(loaded.filteredTrainers.first.hourlyRate, equals(950));

          await bloc.close();
        },
      );

      test(
        'FilterTrainers during in-flight RegisterTrainer is preserved',
        () async {
          final service = ConfigurableMockTrainerService(
            registerDelay: const Duration(milliseconds: 80),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 40));

          bloc.add(
            const RegisterTrainer(
              bio: 'HIIT master',
              certifications: <String>['ACE'],
              specialties: <String>['HIIT'],
              experienceYears: 2,
              hourlyRate: 1100,
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 25));
          expect(bloc.state, isA<TrainerLoading>());
          bloc.add(
            const FilterTrainers(
              TrainerFilterCriteria(selectedSpecialty: 'HIIT'),
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.currentFilter.selectedSpecialty, equals('HIIT'));
          expect(loaded.filteredTrainers.length, equals(2));

          await bloc.close();
        },
      );

      test(
        'FilterTrainers during in-flight UpdateTrainerProfile is preserved',
        () async {
          final service = ConfigurableMockTrainerService(
            updateDelay: const Duration(milliseconds: 80),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 40));

          final coachGamma = service.currentCatalog[2];
          bloc.add(
            UpdateTrainerProfile(
              coachGamma.copyWith(displayName: 'Coach Gamma Super'),
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 25));
          expect(bloc.state, isA<TrainerLoading>());
          bloc.add(
            const FilterTrainers(TrainerFilterCriteria(searchQuery: 'Beta')),
          );

          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.currentFilter.searchQuery, equals('Beta'));
          expect(loaded.filteredTrainers.length, equals(1));
          expect(
            loaded.filteredTrainers.first.displayName,
            equals('Coach Beta'),
          );

          await bloc.close();
        },
      );

      test(
        'Failed RegisterTrainer preserves active filter on error',
        () async {
          final service = ConfigurableMockTrainerService(
            registerFault: Exception('DB error: registration closed'),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 40));

          const activeFilter = TrainerFilterCriteria(
            selectedSpecialty: 'Powerlifting',
          );
          bloc.add(const FilterTrainers(activeFilter));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          bloc.add(
            const RegisterTrainer(
              bio: 'Bio',
              certifications: <String>['NASM'],
              specialties: <String>['Powerlifting'],
              experienceYears: 1,
              hourlyRate: 1000,
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 60));

          expect(bloc.state, isA<TrainerError>());
          final err = bloc.state as TrainerError;
          expect(err.message, contains('Registration failed'));
          expect(bloc.activeFilter, equals(activeFilter));

          bloc.add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 60));

          expect(bloc.state, isA<TrainerLoaded>());
          final reloaded = bloc.state as TrainerLoaded;
          expect(reloaded.currentFilter, equals(activeFilter));
          expect(reloaded.filteredTrainers.length, equals(1));
          expect(
            reloaded.filteredTrainers.first.displayName,
            equals('Coach Alpha'),
          );

          await bloc.close();
        },
      );

      test(
        'Failed UpdateTrainerProfile preserves active filter',
        () async {
          final service = ConfigurableMockTrainerService(
            updateFault: Exception('Row locked by concurrent transaction'),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 40));

          const activeFilter = TrainerFilterCriteria(selectedSpecialty: 'Yoga');
          bloc.add(const FilterTrainers(activeFilter));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final coach = service.currentCatalog[1];
          bloc.add(UpdateTrainerProfile(coach));
          await Future<void>.delayed(const Duration(milliseconds: 60));

          expect(bloc.state, isA<TrainerError>());
          expect(bloc.activeFilter, equals(activeFilter));

          await bloc.close();
        },
      );
    },
  );

  group(
    'Empirical Challenge 3: Adversarial Error & Malformed Payload Resilience',
    () {
      test(
        'TypeError thrown in registerTrainer transitions to TrainerError',
        () async {
          final service = ConfigurableMockTrainerService(
            registerFault: TypeError(),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(
              const RegisterTrainer(
                bio: 'Test',
                certifications: <String>[],
                specialties: <String>[],
                experienceYears: 0,
                hourlyRate: 1000,
              ),
            );

          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(bloc.state, isA<TrainerError>());
          final err = bloc.state as TrainerError;
          expect(err.message, contains('Registration failed'));

          await bloc.close();
        },
      );

      test(
        'TypeError thrown in updateTrainerProfile transitions to TrainerError',
        () async {
          final service = ConfigurableMockTrainerService(
            updateFault: TypeError(),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(
              const UpdateTrainerProfile(
                TrainerProfile(
                  id: 't-test',
                  userId: 'u-test',
                  hourlyRate: 1000,
                ),
              ),
            );

          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(bloc.state, isA<TrainerError>());
          final err = bloc.state as TrainerError;
          expect(err.message, contains('Update failed'));

          await bloc.close();
        },
      );

      test(
        'getMyTrainerProfile throwing does not break LoadTrainers',
        () async {
          final service = ConfigurableMockTrainerService(
            getMyProfileFault: Exception('Failed to fetch personal profile'),
          );
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 60));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.allTrainers.length, equals(3));
          expect(loaded.myProfile, isNull);

          await bloc.close();
        },
      );

      test(
        'Error during LoadTrainers retains previousTrainers in TrainerError',
        () async {
          final errorService = ConfigurableMockTrainerService(
            getTrainersFault: Exception('Cloudflare gateway 502 Bad Gateway'),
          );
          final errorBloc = TrainerBloc(trainerService: errorService)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 40));

          expect(errorBloc.state, isA<TrainerError>());
          final err = errorBloc.state as TrainerError;
          expect(err.message, contains('Failed to load trainers'));

          await errorBloc.close();
        },
      );
    },
  );

  group(
    'Empirical Challenge 4: Catalog State & Filter Criteria Stress Testing',
    () {
      test('Boundary FilterCriteria: negative and infinite maxHourlyRate', () {
        final service = ConfigurableMockTrainerService();
        final catalog = service.currentCatalog;

        const negCriteria = TrainerFilterCriteria(maxHourlyRate: -500);
        expect(catalog.where(negCriteria.matches), isEmpty);

        const infCriteria = TrainerFilterCriteria(
          maxHourlyRate: double.infinity,
        );
        expect(catalog.where(infCriteria.matches).length, equals(3));

        const impossibleRatingCriteria = TrainerFilterCriteria(minRating: 5.01);
        expect(catalog.where(impossibleRatingCriteria.matches), isEmpty);

        const emptySpecialty = TrainerFilterCriteria(selectedSpecialty: '');
        expect(catalog.where(emptySpecialty.matches).length, equals(3));

        const allSpecialty = TrainerFilterCriteria(selectedSpecialty: 'All');
        expect(catalog.where(allSpecialty.matches).length, equals(3));
      });

      test(
        'Non-matching criteria leaves filteredTrainers empty cleanly',
        () async {
          final service = ConfigurableMockTrainerService();
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 50));

          bloc.add(
            const FilterTrainers(
              TrainerFilterCriteria(
                selectedSpecialty: 'Yoga',
                maxHourlyRate: 500,
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 30));

          expect(bloc.state, isA<TrainerLoaded>());
          final loaded = bloc.state as TrainerLoaded;
          expect(loaded.allTrainers.length, equals(3));
          expect(loaded.filteredTrainers, isEmpty);
          expect(loaded.hasActiveFilter, isTrue);

          await bloc.close();
        },
      );

      test(
        'Stress test: 150 randomized rapid events maintain integrity',
        () async {
          final service = ConfigurableMockTrainerService();
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final random = Random(42);
          final specialties = <String>[
            'Strength',
            'Yoga',
            'HIIT',
            'Powerlifting',
            'Mobility',
            'All',
          ];

          for (var i = 0; i < 150; i++) {
            final action = random.nextInt(4);
            switch (action) {
              case 0:
                final spec = specialties[random.nextInt(specialties.length)];
                final maxRate = 500.0 + random.nextInt(2000);
                bloc.add(
                  FilterTrainers(
                    TrainerFilterCriteria(
                      selectedSpecialty: spec,
                      maxHourlyRate: maxRate,
                    ),
                  ),
                );
              case 1:
                bloc.add(const ResetTrainerFilter());
              case 2:
                final catalog = service.currentCatalog;
                final chosen = random.nextBool()
                    ? catalog[random.nextInt(catalog.length)]
                    : null;
                bloc.add(SelectTrainer(chosen));
              case 3:
                bloc.add(const LoadTrainers());
              default:
                break;
            }
          }

          await Future<void>.delayed(const Duration(milliseconds: 250));

          expect(bloc.state, isA<TrainerLoaded>());
          final finalLoaded = bloc.state as TrainerLoaded;
          expect(
            finalLoaded.filteredTrainers.length,
            lessThanOrEqualTo(finalLoaded.allTrainers.length),
          );
          expect(finalLoaded.allTrainers.length, equals(3));

          await bloc.close();
        },
      );
    },
  );

  group(
    'Empirical Challenge 5: Invariant Verification & Conservation Proofs',
    () {
      test(
        'State machine invariant: currentFilter strictly matches activeFilter',
        () async {
          final service = ConfigurableMockTrainerService();
          final bloc = TrainerBloc(trainerService: service)
            ..add(const LoadTrainers());
          await Future<void>.delayed(const Duration(milliseconds: 40));

          const filter1 = TrainerFilterCriteria(selectedSpecialty: 'Mobility');
          bloc.add(const FilterTrainers(filter1));
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(
            (bloc.state as TrainerLoaded).currentFilter,
            equals(bloc.activeFilter),
          );

          bloc.add(const ResetTrainerFilter());
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(
            (bloc.state as TrainerLoaded).currentFilter,
            equals(bloc.activeFilter),
          );
          expect(bloc.activeFilter.isEmpty, isTrue);

          await bloc.close();
        },
      );

      test(
        'Financial invariant holds across 1,000 randomized rates',
        () {
          final random = Random(12345);
          var violations = 0;

          for (var i = 0; i < 1000; i++) {
            final cents = random.nextInt(1000000) + 1;
            final rate = cents / 100.0;
            final feePct = 5.0 + random.nextInt(25);

            final profile = TrainerProfile(
              id: 'test-$i',
              userId: 'user-$i',
              hourlyRate: rate,
              platformFeePct: feePct,
            );

            final fee = profile.platformFeeAmountPerHour;
            final payout = profile.trainerPayoutPerHour;
            final sum = double.parse((fee + payout).toStringAsFixed(2));
            final expectedRate = double.parse(rate.toStringAsFixed(2));

            if ((sum - expectedRate).abs() > 0.0001) {
              violations++;
            }
          }

          expect(
            violations,
            equals(0),
            reason: 'Conservation invariant must hold with 0 discrepancies',
          );
        },
      );
    },
  );
}
