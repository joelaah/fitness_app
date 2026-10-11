// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'routine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoutineExercise {

 String get id; set id(String value); String get exerciseId; set exerciseId(String value); int get sets; set sets(int value); int get reps; set reps(int value); double? get weight; set weight(double? value); int? get restSeconds; set restSeconds(int? value);
/// Create a copy of RoutineExercise
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoutineExerciseCopyWith<RoutineExercise> get copyWith => _$RoutineExerciseCopyWithImpl<RoutineExercise>(this as RoutineExercise, _$identity);

  /// Serializes this RoutineExercise to a JSON map.
  Map<String, dynamic> toJson();




@override
String toString() {
  return 'RoutineExercise(id: $id, exerciseId: $exerciseId, sets: $sets, reps: $reps, weight: $weight, restSeconds: $restSeconds)';
}


}

/// @nodoc
abstract mixin class $RoutineExerciseCopyWith<$Res>  {
  factory $RoutineExerciseCopyWith(RoutineExercise value, $Res Function(RoutineExercise) _then) = _$RoutineExerciseCopyWithImpl;
@useResult
$Res call({
 String id, String exerciseId, int sets, int reps, double? weight, int? restSeconds
});




}
/// @nodoc
class _$RoutineExerciseCopyWithImpl<$Res>
    implements $RoutineExerciseCopyWith<$Res> {
  _$RoutineExerciseCopyWithImpl(this._self, this._then);

  final RoutineExercise _self;
  final $Res Function(RoutineExercise) _then;

/// Create a copy of RoutineExercise
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? exerciseId = null,Object? sets = null,Object? reps = null,Object? weight = freezed,Object? restSeconds = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,reps: null == reps ? _self.reps : reps // ignore: cast_nullable_to_non_nullable
as int,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoutineExercise].
extension RoutineExercisePatterns on RoutineExercise {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoutineExercise value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoutineExercise() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoutineExercise value)  $default,){
final _that = this;
switch (_that) {
case _RoutineExercise():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoutineExercise value)?  $default,){
final _that = this;
switch (_that) {
case _RoutineExercise() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String exerciseId,  int sets,  int reps,  double? weight,  int? restSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoutineExercise() when $default != null:
return $default(_that.id,_that.exerciseId,_that.sets,_that.reps,_that.weight,_that.restSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String exerciseId,  int sets,  int reps,  double? weight,  int? restSeconds)  $default,) {final _that = this;
switch (_that) {
case _RoutineExercise():
return $default(_that.id,_that.exerciseId,_that.sets,_that.reps,_that.weight,_that.restSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String exerciseId,  int sets,  int reps,  double? weight,  int? restSeconds)?  $default,) {final _that = this;
switch (_that) {
case _RoutineExercise() when $default != null:
return $default(_that.id,_that.exerciseId,_that.sets,_that.reps,_that.weight,_that.restSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoutineExercise extends RoutineExercise {
   _RoutineExercise({this.id = '', this.exerciseId = '', this.sets = 3, this.reps = 10, this.weight, this.restSeconds}): super._();
  factory _RoutineExercise.fromJson(Map<String, dynamic> json) => _$RoutineExerciseFromJson(json);

@override@JsonKey()  String id;
@override@JsonKey()  String exerciseId;
@override@JsonKey()  int sets;
@override@JsonKey()  int reps;
@override  double? weight;
@override  int? restSeconds;

/// Create a copy of RoutineExercise
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoutineExerciseCopyWith<_RoutineExercise> get copyWith => __$RoutineExerciseCopyWithImpl<_RoutineExercise>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoutineExerciseToJson(this, );
}



@override
String toString() {
  return 'RoutineExercise(id: $id, exerciseId: $exerciseId, sets: $sets, reps: $reps, weight: $weight, restSeconds: $restSeconds)';
}


}

/// @nodoc
abstract mixin class _$RoutineExerciseCopyWith<$Res> implements $RoutineExerciseCopyWith<$Res> {
  factory _$RoutineExerciseCopyWith(_RoutineExercise value, $Res Function(_RoutineExercise) _then) = __$RoutineExerciseCopyWithImpl;
@override @useResult
$Res call({
 String id, String exerciseId, int sets, int reps, double? weight, int? restSeconds
});




}
/// @nodoc
class __$RoutineExerciseCopyWithImpl<$Res>
    implements _$RoutineExerciseCopyWith<$Res> {
  __$RoutineExerciseCopyWithImpl(this._self, this._then);

  final _RoutineExercise _self;
  final $Res Function(_RoutineExercise) _then;

/// Create a copy of RoutineExercise
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? exerciseId = null,Object? sets = null,Object? reps = null,Object? weight = freezed,Object? restSeconds = freezed,}) {
  return _then(_RoutineExercise(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,reps: null == reps ? _self.reps : reps // ignore: cast_nullable_to_non_nullable
as int,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$WorkoutDay {

 String get id; set id(String value); String get name; set name(String value); List<RoutineExercise> get exercises; set exercises(List<RoutineExercise> value);
/// Create a copy of WorkoutDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutDayCopyWith<WorkoutDay> get copyWith => _$WorkoutDayCopyWithImpl<WorkoutDay>(this as WorkoutDay, _$identity);

  /// Serializes this WorkoutDay to a JSON map.
  Map<String, dynamic> toJson();




@override
String toString() {
  return 'WorkoutDay(id: $id, name: $name, exercises: $exercises)';
}


}

/// @nodoc
abstract mixin class $WorkoutDayCopyWith<$Res>  {
  factory $WorkoutDayCopyWith(WorkoutDay value, $Res Function(WorkoutDay) _then) = _$WorkoutDayCopyWithImpl;
@useResult
$Res call({
 String id, String name, List<RoutineExercise> exercises
});




}
/// @nodoc
class _$WorkoutDayCopyWithImpl<$Res>
    implements $WorkoutDayCopyWith<$Res> {
  _$WorkoutDayCopyWithImpl(this._self, this._then);

  final WorkoutDay _self;
  final $Res Function(WorkoutDay) _then;

/// Create a copy of WorkoutDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? exercises = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,exercises: null == exercises ? _self.exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<RoutineExercise>,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutDay].
extension WorkoutDayPatterns on WorkoutDay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutDay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutDay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutDay value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutDay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutDay value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutDay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  List<RoutineExercise> exercises)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutDay() when $default != null:
return $default(_that.id,_that.name,_that.exercises);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  List<RoutineExercise> exercises)  $default,) {final _that = this;
switch (_that) {
case _WorkoutDay():
return $default(_that.id,_that.name,_that.exercises);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  List<RoutineExercise> exercises)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutDay() when $default != null:
return $default(_that.id,_that.name,_that.exercises);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkoutDay extends WorkoutDay {
   _WorkoutDay({this.id = '', this.name = '', this.exercises = const []}): super._();
  factory _WorkoutDay.fromJson(Map<String, dynamic> json) => _$WorkoutDayFromJson(json);

@override@JsonKey()  String id;
@override@JsonKey()  String name;
@override@JsonKey()  List<RoutineExercise> exercises;

/// Create a copy of WorkoutDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutDayCopyWith<_WorkoutDay> get copyWith => __$WorkoutDayCopyWithImpl<_WorkoutDay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkoutDayToJson(this, );
}



@override
String toString() {
  return 'WorkoutDay(id: $id, name: $name, exercises: $exercises)';
}


}

/// @nodoc
abstract mixin class _$WorkoutDayCopyWith<$Res> implements $WorkoutDayCopyWith<$Res> {
  factory _$WorkoutDayCopyWith(_WorkoutDay value, $Res Function(_WorkoutDay) _then) = __$WorkoutDayCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, List<RoutineExercise> exercises
});




}
/// @nodoc
class __$WorkoutDayCopyWithImpl<$Res>
    implements _$WorkoutDayCopyWith<$Res> {
  __$WorkoutDayCopyWithImpl(this._self, this._then);

  final _WorkoutDay _self;
  final $Res Function(_WorkoutDay) _then;

/// Create a copy of WorkoutDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? exercises = null,}) {
  return _then(_WorkoutDay(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,exercises: null == exercises ? _self.exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<RoutineExercise>,
  ));
}


}


/// @nodoc
mixin _$WorkoutRoutine {

 String get id; set id(String value); String get name; set name(String value); String? get description; set description(String? value); List<WorkoutDay> get days; set days(List<WorkoutDay> value);
/// Create a copy of WorkoutRoutine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutRoutineCopyWith<WorkoutRoutine> get copyWith => _$WorkoutRoutineCopyWithImpl<WorkoutRoutine>(this as WorkoutRoutine, _$identity);

  /// Serializes this WorkoutRoutine to a JSON map.
  Map<String, dynamic> toJson();




@override
String toString() {
  return 'WorkoutRoutine(id: $id, name: $name, description: $description, days: $days)';
}


}

/// @nodoc
abstract mixin class $WorkoutRoutineCopyWith<$Res>  {
  factory $WorkoutRoutineCopyWith(WorkoutRoutine value, $Res Function(WorkoutRoutine) _then) = _$WorkoutRoutineCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, List<WorkoutDay> days
});




}
/// @nodoc
class _$WorkoutRoutineCopyWithImpl<$Res>
    implements $WorkoutRoutineCopyWith<$Res> {
  _$WorkoutRoutineCopyWithImpl(this._self, this._then);

  final WorkoutRoutine _self;
  final $Res Function(WorkoutRoutine) _then;

/// Create a copy of WorkoutRoutine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? days = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as List<WorkoutDay>,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutRoutine].
extension WorkoutRoutinePatterns on WorkoutRoutine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutRoutine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutRoutine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutRoutine value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutRoutine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutRoutine value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutRoutine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  List<WorkoutDay> days)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutRoutine() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.days);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  List<WorkoutDay> days)  $default,) {final _that = this;
switch (_that) {
case _WorkoutRoutine():
return $default(_that.id,_that.name,_that.description,_that.days);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  List<WorkoutDay> days)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutRoutine() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.days);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkoutRoutine extends WorkoutRoutine {
   _WorkoutRoutine({this.id = '', this.name = '', this.description, this.days = const []}): super._();
  factory _WorkoutRoutine.fromJson(Map<String, dynamic> json) => _$WorkoutRoutineFromJson(json);

@override@JsonKey()  String id;
@override@JsonKey()  String name;
@override  String? description;
@override@JsonKey()  List<WorkoutDay> days;

/// Create a copy of WorkoutRoutine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutRoutineCopyWith<_WorkoutRoutine> get copyWith => __$WorkoutRoutineCopyWithImpl<_WorkoutRoutine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkoutRoutineToJson(this, );
}



@override
String toString() {
  return 'WorkoutRoutine(id: $id, name: $name, description: $description, days: $days)';
}


}

/// @nodoc
abstract mixin class _$WorkoutRoutineCopyWith<$Res> implements $WorkoutRoutineCopyWith<$Res> {
  factory _$WorkoutRoutineCopyWith(_WorkoutRoutine value, $Res Function(_WorkoutRoutine) _then) = __$WorkoutRoutineCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, List<WorkoutDay> days
});




}
/// @nodoc
class __$WorkoutRoutineCopyWithImpl<$Res>
    implements _$WorkoutRoutineCopyWith<$Res> {
  __$WorkoutRoutineCopyWithImpl(this._self, this._then);

  final _WorkoutRoutine _self;
  final $Res Function(_WorkoutRoutine) _then;

/// Create a copy of WorkoutRoutine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? days = null,}) {
  return _then(_WorkoutRoutine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as List<WorkoutDay>,
  ));
}


}

// dart format on
