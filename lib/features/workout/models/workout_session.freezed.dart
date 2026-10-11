// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkoutSession {

 String get id; String get routineId; String get dayId; DateTime get startTime; DateTime? get endTime; List<SessionExercise> get exercises; String? get routineName; int? get durationSeconds; double? get totalVolume; int? get totalReps;
/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutSessionCopyWith<WorkoutSession> get copyWith => _$WorkoutSessionCopyWithImpl<WorkoutSession>(this as WorkoutSession, _$identity);

  /// Serializes this WorkoutSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutSession&&(identical(other.id, id) || other.id == id)&&(identical(other.routineId, routineId) || other.routineId == routineId)&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&const DeepCollectionEquality().equals(other.exercises, exercises)&&(identical(other.routineName, routineName) || other.routineName == routineName)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.totalVolume, totalVolume) || other.totalVolume == totalVolume)&&(identical(other.totalReps, totalReps) || other.totalReps == totalReps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,routineId,dayId,startTime,endTime,const DeepCollectionEquality().hash(exercises),routineName,durationSeconds,totalVolume,totalReps);

@override
String toString() {
  return 'WorkoutSession(id: $id, routineId: $routineId, dayId: $dayId, startTime: $startTime, endTime: $endTime, exercises: $exercises, routineName: $routineName, durationSeconds: $durationSeconds, totalVolume: $totalVolume, totalReps: $totalReps)';
}


}

/// @nodoc
abstract mixin class $WorkoutSessionCopyWith<$Res>  {
  factory $WorkoutSessionCopyWith(WorkoutSession value, $Res Function(WorkoutSession) _then) = _$WorkoutSessionCopyWithImpl;
@useResult
$Res call({
 String id, String routineId, String dayId, DateTime startTime, DateTime? endTime, List<SessionExercise> exercises, String? routineName, int? durationSeconds, double? totalVolume, int? totalReps
});




}
/// @nodoc
class _$WorkoutSessionCopyWithImpl<$Res>
    implements $WorkoutSessionCopyWith<$Res> {
  _$WorkoutSessionCopyWithImpl(this._self, this._then);

  final WorkoutSession _self;
  final $Res Function(WorkoutSession) _then;

/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? routineId = null,Object? dayId = null,Object? startTime = null,Object? endTime = freezed,Object? exercises = null,Object? routineName = freezed,Object? durationSeconds = freezed,Object? totalVolume = freezed,Object? totalReps = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,routineId: null == routineId ? _self.routineId : routineId // ignore: cast_nullable_to_non_nullable
as String,dayId: null == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime?,exercises: null == exercises ? _self.exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<SessionExercise>,routineName: freezed == routineName ? _self.routineName : routineName // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,totalVolume: freezed == totalVolume ? _self.totalVolume : totalVolume // ignore: cast_nullable_to_non_nullable
as double?,totalReps: freezed == totalReps ? _self.totalReps : totalReps // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutSession].
extension WorkoutSessionPatterns on WorkoutSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutSession value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutSession value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String routineId,  String dayId,  DateTime startTime,  DateTime? endTime,  List<SessionExercise> exercises,  String? routineName,  int? durationSeconds,  double? totalVolume,  int? totalReps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
return $default(_that.id,_that.routineId,_that.dayId,_that.startTime,_that.endTime,_that.exercises,_that.routineName,_that.durationSeconds,_that.totalVolume,_that.totalReps);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String routineId,  String dayId,  DateTime startTime,  DateTime? endTime,  List<SessionExercise> exercises,  String? routineName,  int? durationSeconds,  double? totalVolume,  int? totalReps)  $default,) {final _that = this;
switch (_that) {
case _WorkoutSession():
return $default(_that.id,_that.routineId,_that.dayId,_that.startTime,_that.endTime,_that.exercises,_that.routineName,_that.durationSeconds,_that.totalVolume,_that.totalReps);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String routineId,  String dayId,  DateTime startTime,  DateTime? endTime,  List<SessionExercise> exercises,  String? routineName,  int? durationSeconds,  double? totalVolume,  int? totalReps)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
return $default(_that.id,_that.routineId,_that.dayId,_that.startTime,_that.endTime,_that.exercises,_that.routineName,_that.durationSeconds,_that.totalVolume,_that.totalReps);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkoutSession implements WorkoutSession {
  const _WorkoutSession({required this.id, required this.routineId, required this.dayId, required this.startTime, this.endTime, final  List<SessionExercise> exercises = const [], this.routineName, this.durationSeconds, this.totalVolume, this.totalReps}): _exercises = exercises;
  factory _WorkoutSession.fromJson(Map<String, dynamic> json) => _$WorkoutSessionFromJson(json);

@override final  String id;
@override final  String routineId;
@override final  String dayId;
@override final  DateTime startTime;
@override final  DateTime? endTime;
 final  List<SessionExercise> _exercises;
@override@JsonKey() List<SessionExercise> get exercises {
  if (_exercises is EqualUnmodifiableListView) return _exercises;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exercises);
}

@override final  String? routineName;
@override final  int? durationSeconds;
@override final  double? totalVolume;
@override final  int? totalReps;

/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutSessionCopyWith<_WorkoutSession> get copyWith => __$WorkoutSessionCopyWithImpl<_WorkoutSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkoutSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutSession&&(identical(other.id, id) || other.id == id)&&(identical(other.routineId, routineId) || other.routineId == routineId)&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&const DeepCollectionEquality().equals(other._exercises, _exercises)&&(identical(other.routineName, routineName) || other.routineName == routineName)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.totalVolume, totalVolume) || other.totalVolume == totalVolume)&&(identical(other.totalReps, totalReps) || other.totalReps == totalReps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,routineId,dayId,startTime,endTime,const DeepCollectionEquality().hash(_exercises),routineName,durationSeconds,totalVolume,totalReps);

@override
String toString() {
  return 'WorkoutSession(id: $id, routineId: $routineId, dayId: $dayId, startTime: $startTime, endTime: $endTime, exercises: $exercises, routineName: $routineName, durationSeconds: $durationSeconds, totalVolume: $totalVolume, totalReps: $totalReps)';
}


}

/// @nodoc
abstract mixin class _$WorkoutSessionCopyWith<$Res> implements $WorkoutSessionCopyWith<$Res> {
  factory _$WorkoutSessionCopyWith(_WorkoutSession value, $Res Function(_WorkoutSession) _then) = __$WorkoutSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String routineId, String dayId, DateTime startTime, DateTime? endTime, List<SessionExercise> exercises, String? routineName, int? durationSeconds, double? totalVolume, int? totalReps
});




}
/// @nodoc
class __$WorkoutSessionCopyWithImpl<$Res>
    implements _$WorkoutSessionCopyWith<$Res> {
  __$WorkoutSessionCopyWithImpl(this._self, this._then);

  final _WorkoutSession _self;
  final $Res Function(_WorkoutSession) _then;

/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? routineId = null,Object? dayId = null,Object? startTime = null,Object? endTime = freezed,Object? exercises = null,Object? routineName = freezed,Object? durationSeconds = freezed,Object? totalVolume = freezed,Object? totalReps = freezed,}) {
  return _then(_WorkoutSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,routineId: null == routineId ? _self.routineId : routineId // ignore: cast_nullable_to_non_nullable
as String,dayId: null == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime?,exercises: null == exercises ? _self._exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<SessionExercise>,routineName: freezed == routineName ? _self.routineName : routineName // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,totalVolume: freezed == totalVolume ? _self.totalVolume : totalVolume // ignore: cast_nullable_to_non_nullable
as double?,totalReps: freezed == totalReps ? _self.totalReps : totalReps // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$SessionExercise {

 String get id; String get exerciseId; List<ExerciseSet> get sets; bool get isSkipped;
/// Create a copy of SessionExercise
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionExerciseCopyWith<SessionExercise> get copyWith => _$SessionExerciseCopyWithImpl<SessionExercise>(this as SessionExercise, _$identity);

  /// Serializes this SessionExercise to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionExercise&&(identical(other.id, id) || other.id == id)&&(identical(other.exerciseId, exerciseId) || other.exerciseId == exerciseId)&&const DeepCollectionEquality().equals(other.sets, sets)&&(identical(other.isSkipped, isSkipped) || other.isSkipped == isSkipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,exerciseId,const DeepCollectionEquality().hash(sets),isSkipped);

@override
String toString() {
  return 'SessionExercise(id: $id, exerciseId: $exerciseId, sets: $sets, isSkipped: $isSkipped)';
}


}

/// @nodoc
abstract mixin class $SessionExerciseCopyWith<$Res>  {
  factory $SessionExerciseCopyWith(SessionExercise value, $Res Function(SessionExercise) _then) = _$SessionExerciseCopyWithImpl;
@useResult
$Res call({
 String id, String exerciseId, List<ExerciseSet> sets, bool isSkipped
});




}
/// @nodoc
class _$SessionExerciseCopyWithImpl<$Res>
    implements $SessionExerciseCopyWith<$Res> {
  _$SessionExerciseCopyWithImpl(this._self, this._then);

  final SessionExercise _self;
  final $Res Function(SessionExercise) _then;

/// Create a copy of SessionExercise
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? exerciseId = null,Object? sets = null,Object? isSkipped = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as List<ExerciseSet>,isSkipped: null == isSkipped ? _self.isSkipped : isSkipped // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionExercise].
extension SessionExercisePatterns on SessionExercise {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionExercise value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionExercise() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionExercise value)  $default,){
final _that = this;
switch (_that) {
case _SessionExercise():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionExercise value)?  $default,){
final _that = this;
switch (_that) {
case _SessionExercise() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String exerciseId,  List<ExerciseSet> sets,  bool isSkipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionExercise() when $default != null:
return $default(_that.id,_that.exerciseId,_that.sets,_that.isSkipped);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String exerciseId,  List<ExerciseSet> sets,  bool isSkipped)  $default,) {final _that = this;
switch (_that) {
case _SessionExercise():
return $default(_that.id,_that.exerciseId,_that.sets,_that.isSkipped);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String exerciseId,  List<ExerciseSet> sets,  bool isSkipped)?  $default,) {final _that = this;
switch (_that) {
case _SessionExercise() when $default != null:
return $default(_that.id,_that.exerciseId,_that.sets,_that.isSkipped);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionExercise implements SessionExercise {
  const _SessionExercise({required this.id, required this.exerciseId, final  List<ExerciseSet> sets = const [], this.isSkipped = false}): _sets = sets;
  factory _SessionExercise.fromJson(Map<String, dynamic> json) => _$SessionExerciseFromJson(json);

@override final  String id;
@override final  String exerciseId;
 final  List<ExerciseSet> _sets;
@override@JsonKey() List<ExerciseSet> get sets {
  if (_sets is EqualUnmodifiableListView) return _sets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sets);
}

@override@JsonKey() final  bool isSkipped;

/// Create a copy of SessionExercise
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionExerciseCopyWith<_SessionExercise> get copyWith => __$SessionExerciseCopyWithImpl<_SessionExercise>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionExerciseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionExercise&&(identical(other.id, id) || other.id == id)&&(identical(other.exerciseId, exerciseId) || other.exerciseId == exerciseId)&&const DeepCollectionEquality().equals(other._sets, _sets)&&(identical(other.isSkipped, isSkipped) || other.isSkipped == isSkipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,exerciseId,const DeepCollectionEquality().hash(_sets),isSkipped);

@override
String toString() {
  return 'SessionExercise(id: $id, exerciseId: $exerciseId, sets: $sets, isSkipped: $isSkipped)';
}


}

/// @nodoc
abstract mixin class _$SessionExerciseCopyWith<$Res> implements $SessionExerciseCopyWith<$Res> {
  factory _$SessionExerciseCopyWith(_SessionExercise value, $Res Function(_SessionExercise) _then) = __$SessionExerciseCopyWithImpl;
@override @useResult
$Res call({
 String id, String exerciseId, List<ExerciseSet> sets, bool isSkipped
});




}
/// @nodoc
class __$SessionExerciseCopyWithImpl<$Res>
    implements _$SessionExerciseCopyWith<$Res> {
  __$SessionExerciseCopyWithImpl(this._self, this._then);

  final _SessionExercise _self;
  final $Res Function(_SessionExercise) _then;

/// Create a copy of SessionExercise
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? exerciseId = null,Object? sets = null,Object? isSkipped = null,}) {
  return _then(_SessionExercise(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,sets: null == sets ? _self._sets : sets // ignore: cast_nullable_to_non_nullable
as List<ExerciseSet>,isSkipped: null == isSkipped ? _self.isSkipped : isSkipped // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ExerciseSet {

 String get id; int get targetReps; double get targetWeight; int? get completedReps; double? get completedWeight; bool get isCompleted;
/// Create a copy of ExerciseSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExerciseSetCopyWith<ExerciseSet> get copyWith => _$ExerciseSetCopyWithImpl<ExerciseSet>(this as ExerciseSet, _$identity);

  /// Serializes this ExerciseSet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExerciseSet&&(identical(other.id, id) || other.id == id)&&(identical(other.targetReps, targetReps) || other.targetReps == targetReps)&&(identical(other.targetWeight, targetWeight) || other.targetWeight == targetWeight)&&(identical(other.completedReps, completedReps) || other.completedReps == completedReps)&&(identical(other.completedWeight, completedWeight) || other.completedWeight == completedWeight)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,targetReps,targetWeight,completedReps,completedWeight,isCompleted);

@override
String toString() {
  return 'ExerciseSet(id: $id, targetReps: $targetReps, targetWeight: $targetWeight, completedReps: $completedReps, completedWeight: $completedWeight, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class $ExerciseSetCopyWith<$Res>  {
  factory $ExerciseSetCopyWith(ExerciseSet value, $Res Function(ExerciseSet) _then) = _$ExerciseSetCopyWithImpl;
@useResult
$Res call({
 String id, int targetReps, double targetWeight, int? completedReps, double? completedWeight, bool isCompleted
});




}
/// @nodoc
class _$ExerciseSetCopyWithImpl<$Res>
    implements $ExerciseSetCopyWith<$Res> {
  _$ExerciseSetCopyWithImpl(this._self, this._then);

  final ExerciseSet _self;
  final $Res Function(ExerciseSet) _then;

/// Create a copy of ExerciseSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? targetReps = null,Object? targetWeight = null,Object? completedReps = freezed,Object? completedWeight = freezed,Object? isCompleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,targetReps: null == targetReps ? _self.targetReps : targetReps // ignore: cast_nullable_to_non_nullable
as int,targetWeight: null == targetWeight ? _self.targetWeight : targetWeight // ignore: cast_nullable_to_non_nullable
as double,completedReps: freezed == completedReps ? _self.completedReps : completedReps // ignore: cast_nullable_to_non_nullable
as int?,completedWeight: freezed == completedWeight ? _self.completedWeight : completedWeight // ignore: cast_nullable_to_non_nullable
as double?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ExerciseSet].
extension ExerciseSetPatterns on ExerciseSet {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExerciseSet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExerciseSet() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExerciseSet value)  $default,){
final _that = this;
switch (_that) {
case _ExerciseSet():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExerciseSet value)?  $default,){
final _that = this;
switch (_that) {
case _ExerciseSet() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int targetReps,  double targetWeight,  int? completedReps,  double? completedWeight,  bool isCompleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExerciseSet() when $default != null:
return $default(_that.id,_that.targetReps,_that.targetWeight,_that.completedReps,_that.completedWeight,_that.isCompleted);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int targetReps,  double targetWeight,  int? completedReps,  double? completedWeight,  bool isCompleted)  $default,) {final _that = this;
switch (_that) {
case _ExerciseSet():
return $default(_that.id,_that.targetReps,_that.targetWeight,_that.completedReps,_that.completedWeight,_that.isCompleted);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int targetReps,  double targetWeight,  int? completedReps,  double? completedWeight,  bool isCompleted)?  $default,) {final _that = this;
switch (_that) {
case _ExerciseSet() when $default != null:
return $default(_that.id,_that.targetReps,_that.targetWeight,_that.completedReps,_that.completedWeight,_that.isCompleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExerciseSet implements ExerciseSet {
  const _ExerciseSet({required this.id, required this.targetReps, required this.targetWeight, this.completedReps, this.completedWeight, this.isCompleted = false});
  factory _ExerciseSet.fromJson(Map<String, dynamic> json) => _$ExerciseSetFromJson(json);

@override final  String id;
@override final  int targetReps;
@override final  double targetWeight;
@override final  int? completedReps;
@override final  double? completedWeight;
@override@JsonKey() final  bool isCompleted;

/// Create a copy of ExerciseSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExerciseSetCopyWith<_ExerciseSet> get copyWith => __$ExerciseSetCopyWithImpl<_ExerciseSet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExerciseSetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExerciseSet&&(identical(other.id, id) || other.id == id)&&(identical(other.targetReps, targetReps) || other.targetReps == targetReps)&&(identical(other.targetWeight, targetWeight) || other.targetWeight == targetWeight)&&(identical(other.completedReps, completedReps) || other.completedReps == completedReps)&&(identical(other.completedWeight, completedWeight) || other.completedWeight == completedWeight)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,targetReps,targetWeight,completedReps,completedWeight,isCompleted);

@override
String toString() {
  return 'ExerciseSet(id: $id, targetReps: $targetReps, targetWeight: $targetWeight, completedReps: $completedReps, completedWeight: $completedWeight, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class _$ExerciseSetCopyWith<$Res> implements $ExerciseSetCopyWith<$Res> {
  factory _$ExerciseSetCopyWith(_ExerciseSet value, $Res Function(_ExerciseSet) _then) = __$ExerciseSetCopyWithImpl;
@override @useResult
$Res call({
 String id, int targetReps, double targetWeight, int? completedReps, double? completedWeight, bool isCompleted
});




}
/// @nodoc
class __$ExerciseSetCopyWithImpl<$Res>
    implements _$ExerciseSetCopyWith<$Res> {
  __$ExerciseSetCopyWithImpl(this._self, this._then);

  final _ExerciseSet _self;
  final $Res Function(_ExerciseSet) _then;

/// Create a copy of ExerciseSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? targetReps = null,Object? targetWeight = null,Object? completedReps = freezed,Object? completedWeight = freezed,Object? isCompleted = null,}) {
  return _then(_ExerciseSet(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,targetReps: null == targetReps ? _self.targetReps : targetReps // ignore: cast_nullable_to_non_nullable
as int,targetWeight: null == targetWeight ? _self.targetWeight : targetWeight // ignore: cast_nullable_to_non_nullable
as double,completedReps: freezed == completedReps ? _self.completedReps : completedReps // ignore: cast_nullable_to_non_nullable
as int?,completedWeight: freezed == completedWeight ? _self.completedWeight : completedWeight // ignore: cast_nullable_to_non_nullable
as double?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
