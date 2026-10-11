import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:uuid/uuid.dart';

RoutineExercise _ex(String id, int sets, int reps) => RoutineExercise(
  id: const Uuid().v4(),
  exerciseId: id,
  sets: sets,
  reps: reps,
);

class RoutineTemplates {
  // 1. Upper / Lower (4 Days - The Gold Standard)
  static final WorkoutRoutine upperLower = WorkoutRoutine(
    id: const Uuid().v4(),
    name: 'Upper / Lower',
    description:
        'A 4-day split alternating between upper body and lower body for optimal recovery and consistent growth.',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Upper Body A',
        exercises: [
          _ex('0314', 3, 10), // Incline DB Press [Upper Chest]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0091', 3, 8), // Barbell Overhead Press [Front Delts]
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
          _ex('0031', 3, 10), // Barbell Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Lower Body A',
        exercises: [
          _ex('0043', 3, 8), // Barbell Full Squat [Quads]
          _ex('0085', 3, 10), // Barbell Romanian Deadlift [Hamstrings]
          _ex('0585', 3, 12), // Lever Leg Extension [Quads]
          _ex('0088', 3, 15), // Barbell Seated Calf Raise [Calves]
          _ex('0472', 3, 12), // Hanging Leg Raise [Abs]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Upper Body B',
        exercises: [
          _ex('0025', 3, 8), // Barbell Bench Press [Mid Chest]
          _ex('0652', 3, 8), // Pull-up [Lats]
          _ex('0334', 3, 12), // DB Lateral Raise [Side Delts]
          _ex('0861', 3, 10), // Cable Seated Row [Upper Back]
          _ex('0056', 3, 10), // Tricep Extension [Triceps]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Lower Body B',
        exercises: [
          _ex('0032', 3, 6), // Barbell Deadlift [Back/Hamstrings]
          _ex('0739', 3, 10), // Sled 45 Leg Press [Quads/Glutes]
          _ex('0586', 3, 12), // Lever Lying Leg Curl [Hamstrings]
          _ex('0088', 3, 15), // Barbell Seated Calf Raise [Calves]
          _ex('0472', 3, 12), // Hanging Leg Raise [Abs]
        ],
      ),
    ],
  );

  // 2. 5-Day PPL + Upper/Lower Hybrid
  static final WorkoutRoutine pplHybrid = WorkoutRoutine(
    id: const Uuid().v4(),
    name: '5-Day PPL + Upper/Lower',
    description:
        'The modern lifter favorite: 3 days of PPL isolation, 2 days of Upper/Lower power, with 2 full rest days.',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Push (Chest & Shoulders)',
        exercises: [
          _ex('0314', 3, 10), // Incline DB Press [Upper Chest]
          _ex('0025', 3, 8), // Barbell Bench Press [Mid Chest]
          _ex('0251', 3, 10), // Chest Dip [Lower Chest]
          _ex('0334', 3, 12), // DB Lateral Raise [Side Delts]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Pull (Back & Biceps)',
        exercises: [
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0861', 3, 10), // Cable Seated Row [Upper Back]
          _ex('0380', 3, 15), // DB Rear Lateral Raise [Rear Delts]
          _ex('0031', 3, 10), // Barbell Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Legs (Quads & Hams)',
        exercises: [
          _ex('0043', 3, 8), // Barbell Full Squat [Quads]
          _ex('0085', 3, 10), // Barbell Romanian Deadlift [Hamstrings]
          _ex('0585', 3, 12), // Lever Leg Extension [Quads]
          _ex('0586', 3, 12), // Lever Lying Leg Curl [Hamstrings]
          _ex('0088', 3, 15), // Barbell Seated Calf Raise [Calves]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Upper Body Power',
        exercises: [
          _ex('0047', 3, 8), // Incline Barbell Bench [Upper Chest]
          _ex('0652', 3, 8), // Pull-up [Lats]
          _ex('0091', 3, 8), // Barbell Overhead Press [Front Delts]
          _ex('0334', 3, 12), // DB Lateral Raise [Side Delts]
          _ex('0056', 3, 10), // Skull Crusher [Triceps]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Lower Body & Core',
        exercises: [
          _ex('0032', 3, 6), // Barbell Deadlift [Back/Hams]
          _ex('0739', 3, 10), // Sled 45 Leg Press [Quads/Glutes]
          _ex('0088', 3, 15), // Calf Raise [Calves]
          _ex('0472', 3, 12), // Hanging Leg Raise [Abs]
        ],
      ),
    ],
  );

  // 3. Classic 5-Day "Bro Split" (Bodypart Split)
  static final WorkoutRoutine broSplit = WorkoutRoutine(
    id: const Uuid().v4(),
    name: 'Classic Bro Split',
    description:
        'Dedicated 5-day bodypart split: Chest, Back, Shoulders, Legs, and Arms for maximum single-muscle volume.',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Chest Day',
        exercises: [
          _ex('0314', 3, 10), // Incline DB Press [Upper Chest]
          _ex('0025', 3, 8), // Barbell Bench Press [Mid Chest]
          _ex('0251', 3, 10), // Chest Dip [Lower Chest]
          _ex('0171', 3, 12), // Cable Incline Fly [Upper Chest]
          _ex('0158', 3, 12), // Cable Decline Fly [Lower Chest]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Back Day',
        exercises: [
          _ex('0032', 3, 6), // Barbell Deadlift [Lower Back/Spine]
          _ex('0652', 3, 8), // Pull-up [Lats]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0861', 3, 10), // Cable Seated Row [Upper Back]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Shoulder Day',
        exercises: [
          _ex('0091', 3, 8), // Barbell Overhead Press [Front Delts]
          _ex('0426', 3, 10), // DB Standing Overhead Press [Front Delts]
          _ex('0334', 4, 12), // DB Lateral Raise [Side Delts]
          _ex('0380', 3, 15), // DB Rear Lateral Raise [Rear Delts]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Leg Day',
        exercises: [
          _ex('0043', 3, 8), // Barbell Full Squat [Quads]
          _ex('0085', 3, 10), // Romanian Deadlift [Hamstrings]
          _ex('0739', 3, 10), // Sled 45 Leg Press [Quads/Glutes]
          _ex('0585', 3, 12), // Leg Extension [Quads]
          _ex('0586', 3, 12), // Leg Curl [Hamstrings]
          _ex('0088', 3, 15), // Calf Raise [Calves]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Arms & Abs Day',
        exercises: [
          _ex('0031', 3, 10), // Barbell Curl [Biceps]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
          _ex('0056', 3, 10), // Lying Close-Grip Extension [Triceps]
          _ex('0472', 3, 12), // Hanging Leg Raise [Abs]
        ],
      ),
    ],
  );

  // 4. PHUL (4-Day Power Hypertrophy)
  static final WorkoutRoutine phul = WorkoutRoutine(
    id: const Uuid().v4(),
    name: 'PHUL (Power & Size)',
    description:
        '4-day split blending heavy powerlifting strength (days 1-2) with high-rep bodybuilding pumps (days 3-4).',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Upper Power',
        exercises: [
          _ex('0025', 4, 5), // Barbell Bench Press (Heavy 5 reps)
          _ex('0027', 4, 5), // Barbell Bent Over Row (Heavy 5 reps)
          _ex('0091', 3, 6), // Overhead Press (Heavy 6 reps)
          _ex('0031', 3, 8), // Barbell Curl
          _ex('0056', 3, 8), // Skull Crusher
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Lower Power',
        exercises: [
          _ex('0043', 4, 5), // Barbell Full Squat (Heavy 5 reps)
          _ex('0032', 3, 5), // Barbell Deadlift (Heavy 5 reps)
          _ex('0739', 3, 8), // Sled 45 Leg Press
          _ex('0088', 3, 10), // Calf Raise
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Upper Hypertrophy',
        exercises: [
          _ex('0314', 3, 10), // Incline DB Press [Upper Chest]
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0861', 3, 12), // Cable Seated Row [Upper Back]
          _ex('0334', 4, 12), // DB Lateral Raise [Side Delts]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
          _ex('0313', 3, 12), // DB Hammer Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Lower Hypertrophy',
        exercises: [
          _ex('0085', 3, 10), // Romanian Deadlift [Hamstrings]
          _ex('0585', 3, 12), // Leg Extension [Quads]
          _ex('0586', 3, 12), // Leg Curl [Hamstrings]
          _ex('0088', 3, 15), // Calf Raise [Calves]
          _ex('0472', 3, 12), // Hanging Leg Raise [Abs]
        ],
      ),
    ],
  );

  // 5. Torso / Limbs (4-Day)
  static final WorkoutRoutine torsoLimbs = WorkoutRoutine(
    id: const Uuid().v4(),
    name: 'Torso / Limbs',
    description:
        'Separates torso (chest, back, shoulders) from extremities (legs, arms). Great for athletic development.',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Torso A',
        exercises: [
          _ex('0025', 3, 8), // Barbell Bench Press [Mid Chest]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0314', 3, 10), // Incline DB Press [Upper Chest]
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0091', 3, 8), // Overhead Press [Front Delts]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Limbs A (Legs & Arms)',
        exercises: [
          _ex('0043', 3, 8), // Barbell Squat [Quads]
          _ex('0085', 3, 10), // Romanian Deadlift [Hamstrings]
          _ex('0031', 3, 10), // Barbell Curl [Biceps]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
          _ex('0088', 3, 15), // Calf Raise [Calves]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Torso B',
        exercises: [
          _ex('0047', 3, 8), // Incline Barbell Bench [Upper Chest]
          _ex('0652', 3, 8), // Pull-up [Lats]
          _ex('0251', 3, 10), // Chest Dip [Lower Chest]
          _ex('0861', 3, 10), // Cable Seated Row [Upper Back]
          _ex('0334', 3, 12), // DB Lateral Raise [Side Delts]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Limbs B (Legs & Arms)',
        exercises: [
          _ex('0739', 3, 10), // Sled 45 Leg Press [Quads/Glutes]
          _ex('0586', 3, 12), // Leg Curl [Hamstrings]
          _ex('0585', 3, 12), // Leg Extension [Quads]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
          _ex('0056', 3, 10), // Skull Crusher [Triceps]
          _ex('0088', 3, 15), // Calf Raise [Calves]
        ],
      ),
    ],
  );

  // 6. Push Pull Legs (PPL - 6 Days)
  static final WorkoutRoutine ppl = WorkoutRoutine(
    id: const Uuid().v4(),
    name: 'Push Pull Legs (PPL)',
    description:
        'A classic 6-day split focusing on push, pull, and leg movements with complete muscle balance.',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Push (Chest Focus)',
        exercises: [
          _ex('0314', 3, 10), // Incline DB Bench Press [Upper Chest]
          _ex('0025', 3, 8), // Barbell Bench Press [Mid Chest]
          _ex('0251', 3, 10), // Chest Dip [Lower Chest]
          _ex('0334', 3, 12), // DB Lateral Raise [Side Delts]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Pull (Lats & Biceps)',
        exercises: [
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0861', 3, 10), // Cable Seated Row [Upper Back]
          _ex('0380', 3, 15), // DB Rear Lateral Raise [Rear Delts]
          _ex('0031', 3, 10), // Barbell Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Legs (Quad Focus)',
        exercises: [
          _ex('0043', 3, 8), // Barbell Full Squat [Quads]
          _ex('0085', 3, 10), // Barbell Romanian Deadlift [Hamstrings]
          _ex('0585', 3, 12), // Lever Leg Extension [Quads]
          _ex('0088', 3, 15), // Barbell Seated Calf Raise [Calves]
          _ex('0472', 3, 12), // Hanging Leg Raise [Abs]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Push (Shoulder Focus)',
        exercises: [
          _ex('0091', 3, 8), // Barbell Seated Overhead Press [Front Delts]
          _ex('0047', 3, 8), // Barbell Incline Bench Press [Upper Chest]
          _ex('0158', 3, 12), // Cable Decline Fly [Lower Chest]
          _ex('0334', 4, 12), // DB Lateral Raise [Side Delts]
          _ex('0056', 3, 10), // Lying Close-Grip Triceps Extension [Triceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Pull (Back Thickness & Arms)',
        exercises: [
          _ex('0652', 3, 8), // Pull-up [Lats]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0380', 3, 15), // DB Rear Lateral Raise [Rear Delts]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Legs (Hamstrings & Glutes)',
        exercises: [
          _ex('0085', 3, 8), // Barbell Romanian Deadlift [Hamstrings]
          _ex('0739', 3, 10), // Sled 45 Leg Press [Quads/Glutes]
          _ex('0586', 3, 12), // Lever Lying Leg Curl [Hamstrings]
          _ex('0088', 3, 15), // Barbell Seated Calf Raise [Calves]
          _ex('0472', 3, 12), // Hanging Leg Raise [Abs]
        ],
      ),
    ],
  );

  // 7. Arnold Split (6 Days)
  static final WorkoutRoutine arnold = WorkoutRoutine(
    id: const Uuid().v4(),
    name: 'Arnold Split',
    description:
        'A 6-day split grouped by Chest/Back, Shoulders/Arms, and Legs for legendary pump and hypertrophy.',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Chest & Back A',
        exercises: [
          _ex('0025', 3, 8), // Barbell Bench Press [Mid Chest]
          _ex('0314', 3, 10), // Incline DB Press [Upper Chest]
          _ex('0652', 3, 8), // Pull-up [Lats]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0158', 3, 12), // Cable Decline Fly [Lower Chest]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Shoulders & Arms A',
        exercises: [
          _ex('0091', 3, 8), // Barbell Overhead Press [Front Delts]
          _ex('0334', 4, 12), // DB Lateral Raise [Side Delts]
          _ex('0380', 3, 15), // DB Rear Lateral Raise [Rear Delts]
          _ex('0031', 3, 10), // Barbell Curl [Biceps]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Legs A',
        exercises: [
          _ex('0043', 3, 8), // Barbell Full Squat [Quads]
          _ex('0085', 3, 10), // Romanian Deadlift [Hamstrings]
          _ex('0585', 3, 12), // Leg Extension [Quads]
          _ex('0586', 3, 12), // Leg Curl [Hamstrings]
          _ex('0088', 3, 15), // Calf Raise [Calves]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Chest & Back B',
        exercises: [
          _ex('0047', 3, 8), // Incline Barbell Bench [Upper Chest]
          _ex('0251', 3, 10), // Chest Dip [Lower Chest]
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0861', 3, 10), // Cable Seated Row [Upper Back]
          _ex('0171', 3, 12), // Cable Incline Fly [Upper Chest]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Shoulders & Arms B',
        exercises: [
          _ex('0426', 3, 8), // DB Standing Overhead Press [Front Delts]
          _ex('0334', 4, 12), // DB Lateral Raise [Side Delts]
          _ex('0380', 3, 15), // DB Rear Lateral Raise [Rear Delts]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
          _ex('0056', 3, 10), // Tricep Extension [Triceps]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Legs B',
        exercises: [
          _ex('0085', 3, 8), // Romanian Deadlift [Hamstrings]
          _ex('0739', 3, 10), // Sled 45 Leg Press [Quads/Glutes]
          _ex('0586', 3, 12), // Leg Curl [Hamstrings]
          _ex('0585', 3, 12), // Leg Extension [Quads]
          _ex('0088', 3, 15), // Calf Raise [Calves]
        ],
      ),
    ],
  );

  // 8. Full Body (3 Days)
  static final WorkoutRoutine fullBody = WorkoutRoutine(
    id: const Uuid().v4(),
    name: 'Full Body',
    description:
        'A 3-day split training the entire body each session. Maximum efficiency for busy schedules.',
    days: [
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Full Body A',
        exercises: [
          _ex('0043', 3, 8), // Barbell Full Squat [Quads]
          _ex('0025', 3, 8), // Barbell Bench Press [Mid Chest]
          _ex('0027', 3, 8), // Barbell Bent Over Row [Upper Back]
          _ex('0091', 3, 8), // Barbell Overhead Press [Front Delts]
          _ex('0031', 3, 10), // Barbell Curl [Biceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Full Body B',
        exercises: [
          _ex('0085', 3, 8), // Romanian Deadlift [Hamstrings]
          _ex('0314', 3, 10), // Incline DB Press [Upper Chest]
          _ex('0198', 3, 10), // Cable Pulldown [Lats]
          _ex('0334', 3, 12), // DB Lateral Raise [Side Delts]
          _ex('0201', 3, 12), // Cable Pushdown [Triceps]
        ],
      ),
      WorkoutDay(
        id: const Uuid().v4(),
        name: 'Full Body C',
        exercises: [
          _ex('0739', 3, 10), // Sled 45 Leg Press [Quads]
          _ex('0251', 3, 10), // Chest Dip [Lower Chest]
          _ex('0861', 3, 10), // Cable Seated Row [Upper Back]
          _ex('0586', 3, 12), // Lever Lying Leg Curl [Hamstrings]
          _ex('0313', 3, 10), // DB Hammer Curl [Biceps]
        ],
      ),
    ],
  );
}
