// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exercise.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Exercise {

 String get id; String get name; String get category;@JsonKey(name: 'body_part') String get bodyPart; String get equipment; Map<String, dynamic> get instructions;@JsonKey(name: 'instruction_steps') Map<String, dynamic> get instructionSteps;@JsonKey(name: 'muscle_group') String get muscleGroup;@JsonKey(name: 'secondary_muscles') List<String> get secondaryMuscles; String get target; String get image;@JsonKey(name: 'gif_url') String get gifUrl; String get attribution;
/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExerciseCopyWith<Exercise> get copyWith => _$ExerciseCopyWithImpl<Exercise>(this as Exercise, _$identity);

  /// Serializes this Exercise to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Exercise&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.bodyPart, bodyPart) || other.bodyPart == bodyPart)&&(identical(other.equipment, equipment) || other.equipment == equipment)&&const DeepCollectionEquality().equals(other.instructions, instructions)&&const DeepCollectionEquality().equals(other.instructionSteps, instructionSteps)&&(identical(other.muscleGroup, muscleGroup) || other.muscleGroup == muscleGroup)&&const DeepCollectionEquality().equals(other.secondaryMuscles, secondaryMuscles)&&(identical(other.target, target) || other.target == target)&&(identical(other.image, image) || other.image == image)&&(identical(other.gifUrl, gifUrl) || other.gifUrl == gifUrl)&&(identical(other.attribution, attribution) || other.attribution == attribution));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,category,bodyPart,equipment,const DeepCollectionEquality().hash(instructions),const DeepCollectionEquality().hash(instructionSteps),muscleGroup,const DeepCollectionEquality().hash(secondaryMuscles),target,image,gifUrl,attribution);

@override
String toString() {
  return 'Exercise(id: $id, name: $name, category: $category, bodyPart: $bodyPart, equipment: $equipment, instructions: $instructions, instructionSteps: $instructionSteps, muscleGroup: $muscleGroup, secondaryMuscles: $secondaryMuscles, target: $target, image: $image, gifUrl: $gifUrl, attribution: $attribution)';
}


}

/// @nodoc
abstract mixin class $ExerciseCopyWith<$Res>  {
  factory $ExerciseCopyWith(Exercise value, $Res Function(Exercise) _then) = _$ExerciseCopyWithImpl;
@useResult
$Res call({
 String id, String name, String category,@JsonKey(name: 'body_part') String bodyPart, String equipment, Map<String, dynamic> instructions,@JsonKey(name: 'instruction_steps') Map<String, dynamic> instructionSteps,@JsonKey(name: 'muscle_group') String muscleGroup,@JsonKey(name: 'secondary_muscles') List<String> secondaryMuscles, String target, String image,@JsonKey(name: 'gif_url') String gifUrl, String attribution
});




}
/// @nodoc
class _$ExerciseCopyWithImpl<$Res>
    implements $ExerciseCopyWith<$Res> {
  _$ExerciseCopyWithImpl(this._self, this._then);

  final Exercise _self;
  final $Res Function(Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? category = null,Object? bodyPart = null,Object? equipment = null,Object? instructions = null,Object? instructionSteps = null,Object? muscleGroup = null,Object? secondaryMuscles = null,Object? target = null,Object? image = null,Object? gifUrl = null,Object? attribution = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,bodyPart: null == bodyPart ? _self.bodyPart : bodyPart // ignore: cast_nullable_to_non_nullable
as String,equipment: null == equipment ? _self.equipment : equipment // ignore: cast_nullable_to_non_nullable
as String,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,instructionSteps: null == instructionSteps ? _self.instructionSteps : instructionSteps // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,muscleGroup: null == muscleGroup ? _self.muscleGroup : muscleGroup // ignore: cast_nullable_to_non_nullable
as String,secondaryMuscles: null == secondaryMuscles ? _self.secondaryMuscles : secondaryMuscles // ignore: cast_nullable_to_non_nullable
as List<String>,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,gifUrl: null == gifUrl ? _self.gifUrl : gifUrl // ignore: cast_nullable_to_non_nullable
as String,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Exercise].
extension ExercisePatterns on Exercise {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Exercise value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Exercise() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Exercise value)  $default,){
final _that = this;
switch (_that) {
case _Exercise():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Exercise value)?  $default,){
final _that = this;
switch (_that) {
case _Exercise() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String category, @JsonKey(name: 'body_part')  String bodyPart,  String equipment,  Map<String, dynamic> instructions, @JsonKey(name: 'instruction_steps')  Map<String, dynamic> instructionSteps, @JsonKey(name: 'muscle_group')  String muscleGroup, @JsonKey(name: 'secondary_muscles')  List<String> secondaryMuscles,  String target,  String image, @JsonKey(name: 'gif_url')  String gifUrl,  String attribution)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.bodyPart,_that.equipment,_that.instructions,_that.instructionSteps,_that.muscleGroup,_that.secondaryMuscles,_that.target,_that.image,_that.gifUrl,_that.attribution);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String category, @JsonKey(name: 'body_part')  String bodyPart,  String equipment,  Map<String, dynamic> instructions, @JsonKey(name: 'instruction_steps')  Map<String, dynamic> instructionSteps, @JsonKey(name: 'muscle_group')  String muscleGroup, @JsonKey(name: 'secondary_muscles')  List<String> secondaryMuscles,  String target,  String image, @JsonKey(name: 'gif_url')  String gifUrl,  String attribution)  $default,) {final _that = this;
switch (_that) {
case _Exercise():
return $default(_that.id,_that.name,_that.category,_that.bodyPart,_that.equipment,_that.instructions,_that.instructionSteps,_that.muscleGroup,_that.secondaryMuscles,_that.target,_that.image,_that.gifUrl,_that.attribution);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String category, @JsonKey(name: 'body_part')  String bodyPart,  String equipment,  Map<String, dynamic> instructions, @JsonKey(name: 'instruction_steps')  Map<String, dynamic> instructionSteps, @JsonKey(name: 'muscle_group')  String muscleGroup, @JsonKey(name: 'secondary_muscles')  List<String> secondaryMuscles,  String target,  String image, @JsonKey(name: 'gif_url')  String gifUrl,  String attribution)?  $default,) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.bodyPart,_that.equipment,_that.instructions,_that.instructionSteps,_that.muscleGroup,_that.secondaryMuscles,_that.target,_that.image,_that.gifUrl,_that.attribution);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Exercise extends Exercise {
  const _Exercise({this.id = '', this.name = '', this.category = '', @JsonKey(name: 'body_part') this.bodyPart = '', this.equipment = '', final  Map<String, dynamic> instructions = const <String, dynamic>{}, @JsonKey(name: 'instruction_steps') final  Map<String, dynamic> instructionSteps = const <String, dynamic>{}, @JsonKey(name: 'muscle_group') this.muscleGroup = '', @JsonKey(name: 'secondary_muscles') final  List<String> secondaryMuscles = const <String>[], this.target = '', this.image = '', @JsonKey(name: 'gif_url') this.gifUrl = '', this.attribution = ''}): _instructions = instructions,_instructionSteps = instructionSteps,_secondaryMuscles = secondaryMuscles,super._();
  factory _Exercise.fromJson(Map<String, dynamic> json) => _$ExerciseFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String category;
@override@JsonKey(name: 'body_part') final  String bodyPart;
@override@JsonKey() final  String equipment;
 final  Map<String, dynamic> _instructions;
@override@JsonKey() Map<String, dynamic> get instructions {
  if (_instructions is EqualUnmodifiableMapView) return _instructions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_instructions);
}

 final  Map<String, dynamic> _instructionSteps;
@override@JsonKey(name: 'instruction_steps') Map<String, dynamic> get instructionSteps {
  if (_instructionSteps is EqualUnmodifiableMapView) return _instructionSteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_instructionSteps);
}

@override@JsonKey(name: 'muscle_group') final  String muscleGroup;
 final  List<String> _secondaryMuscles;
@override@JsonKey(name: 'secondary_muscles') List<String> get secondaryMuscles {
  if (_secondaryMuscles is EqualUnmodifiableListView) return _secondaryMuscles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_secondaryMuscles);
}

@override@JsonKey() final  String target;
@override@JsonKey() final  String image;
@override@JsonKey(name: 'gif_url') final  String gifUrl;
@override@JsonKey() final  String attribution;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExerciseCopyWith<_Exercise> get copyWith => __$ExerciseCopyWithImpl<_Exercise>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExerciseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Exercise&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.bodyPart, bodyPart) || other.bodyPart == bodyPart)&&(identical(other.equipment, equipment) || other.equipment == equipment)&&const DeepCollectionEquality().equals(other._instructions, _instructions)&&const DeepCollectionEquality().equals(other._instructionSteps, _instructionSteps)&&(identical(other.muscleGroup, muscleGroup) || other.muscleGroup == muscleGroup)&&const DeepCollectionEquality().equals(other._secondaryMuscles, _secondaryMuscles)&&(identical(other.target, target) || other.target == target)&&(identical(other.image, image) || other.image == image)&&(identical(other.gifUrl, gifUrl) || other.gifUrl == gifUrl)&&(identical(other.attribution, attribution) || other.attribution == attribution));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,category,bodyPart,equipment,const DeepCollectionEquality().hash(_instructions),const DeepCollectionEquality().hash(_instructionSteps),muscleGroup,const DeepCollectionEquality().hash(_secondaryMuscles),target,image,gifUrl,attribution);

@override
String toString() {
  return 'Exercise(id: $id, name: $name, category: $category, bodyPart: $bodyPart, equipment: $equipment, instructions: $instructions, instructionSteps: $instructionSteps, muscleGroup: $muscleGroup, secondaryMuscles: $secondaryMuscles, target: $target, image: $image, gifUrl: $gifUrl, attribution: $attribution)';
}


}

/// @nodoc
abstract mixin class _$ExerciseCopyWith<$Res> implements $ExerciseCopyWith<$Res> {
  factory _$ExerciseCopyWith(_Exercise value, $Res Function(_Exercise) _then) = __$ExerciseCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String category,@JsonKey(name: 'body_part') String bodyPart, String equipment, Map<String, dynamic> instructions,@JsonKey(name: 'instruction_steps') Map<String, dynamic> instructionSteps,@JsonKey(name: 'muscle_group') String muscleGroup,@JsonKey(name: 'secondary_muscles') List<String> secondaryMuscles, String target, String image,@JsonKey(name: 'gif_url') String gifUrl, String attribution
});




}
/// @nodoc
class __$ExerciseCopyWithImpl<$Res>
    implements _$ExerciseCopyWith<$Res> {
  __$ExerciseCopyWithImpl(this._self, this._then);

  final _Exercise _self;
  final $Res Function(_Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? category = null,Object? bodyPart = null,Object? equipment = null,Object? instructions = null,Object? instructionSteps = null,Object? muscleGroup = null,Object? secondaryMuscles = null,Object? target = null,Object? image = null,Object? gifUrl = null,Object? attribution = null,}) {
  return _then(_Exercise(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,bodyPart: null == bodyPart ? _self.bodyPart : bodyPart // ignore: cast_nullable_to_non_nullable
as String,equipment: null == equipment ? _self.equipment : equipment // ignore: cast_nullable_to_non_nullable
as String,instructions: null == instructions ? _self._instructions : instructions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,instructionSteps: null == instructionSteps ? _self._instructionSteps : instructionSteps // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,muscleGroup: null == muscleGroup ? _self.muscleGroup : muscleGroup // ignore: cast_nullable_to_non_nullable
as String,secondaryMuscles: null == secondaryMuscles ? _self._secondaryMuscles : secondaryMuscles // ignore: cast_nullable_to_non_nullable
as List<String>,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,gifUrl: null == gifUrl ? _self.gifUrl : gifUrl // ignore: cast_nullable_to_non_nullable
as String,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
