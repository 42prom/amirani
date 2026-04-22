// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'l10n_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$L10nState {
  /// Active language code: 'en' or whatever the gym configured (e.g. 'ka').
  String get lang => throw _privateConstructorUsedError;

  /// Integer version of the cached alternative pack (0 = none cached).
  int get version => throw _privateConstructorUsedError;

  /// Language CODE of the alternative language, e.g. 'ka'.
  /// Preserved when the user switches back to English so the flag pill
  /// always knows which alt flag to display.
  String? get altLangCode => throw _privateConstructorUsedError;

  /// Native-script display name for the alternative language, e.g. 'ქართული'.
  /// Null when no alternative language is configured.
  String? get altLangName => throw _privateConstructorUsedError;

  /// True while the language pack is downloading in the background.
  bool get isDownloading => throw _privateConstructorUsedError;

  /// Set when a download attempt fails. Cleared by clearError().
  String? get downloadError => throw _privateConstructorUsedError;

  /// True once a valid alternative pack is loaded in the notifier.
  /// Drives visibility of the language toggle in Settings.
  bool get hasAlternative => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $L10nStateCopyWith<L10nState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $L10nStateCopyWith<$Res> {
  factory $L10nStateCopyWith(L10nState value, $Res Function(L10nState) then) =
      _$L10nStateCopyWithImpl<$Res, L10nState>;
  @useResult
  $Res call(
      {String lang,
      int version,
      String? altLangCode,
      String? altLangName,
      bool isDownloading,
      String? downloadError,
      bool hasAlternative});
}

/// @nodoc
class _$L10nStateCopyWithImpl<$Res, $Val extends L10nState>
    implements $L10nStateCopyWith<$Res> {
  _$L10nStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lang = null,
    Object? version = null,
    Object? altLangCode = freezed,
    Object? altLangName = freezed,
    Object? isDownloading = null,
    Object? downloadError = freezed,
    Object? hasAlternative = null,
  }) {
    return _then(_value.copyWith(
      lang: null == lang
          ? _value.lang
          : lang // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      altLangCode: freezed == altLangCode
          ? _value.altLangCode
          : altLangCode // ignore: cast_nullable_to_non_nullable
              as String?,
      altLangName: freezed == altLangName
          ? _value.altLangName
          : altLangName // ignore: cast_nullable_to_non_nullable
              as String?,
      isDownloading: null == isDownloading
          ? _value.isDownloading
          : isDownloading // ignore: cast_nullable_to_non_nullable
              as bool,
      downloadError: freezed == downloadError
          ? _value.downloadError
          : downloadError // ignore: cast_nullable_to_non_nullable
              as String?,
      hasAlternative: null == hasAlternative
          ? _value.hasAlternative
          : hasAlternative // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$L10nStateImplCopyWith<$Res>
    implements $L10nStateCopyWith<$Res> {
  factory _$$L10nStateImplCopyWith(
          _$L10nStateImpl value, $Res Function(_$L10nStateImpl) then) =
      __$$L10nStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String lang,
      int version,
      String? altLangCode,
      String? altLangName,
      bool isDownloading,
      String? downloadError,
      bool hasAlternative});
}

/// @nodoc
class __$$L10nStateImplCopyWithImpl<$Res>
    extends _$L10nStateCopyWithImpl<$Res, _$L10nStateImpl>
    implements _$$L10nStateImplCopyWith<$Res> {
  __$$L10nStateImplCopyWithImpl(
      _$L10nStateImpl _value, $Res Function(_$L10nStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lang = null,
    Object? version = null,
    Object? altLangCode = freezed,
    Object? altLangName = freezed,
    Object? isDownloading = null,
    Object? downloadError = freezed,
    Object? hasAlternative = null,
  }) {
    return _then(_$L10nStateImpl(
      lang: null == lang
          ? _value.lang
          : lang // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      altLangCode: freezed == altLangCode
          ? _value.altLangCode
          : altLangCode // ignore: cast_nullable_to_non_nullable
              as String?,
      altLangName: freezed == altLangName
          ? _value.altLangName
          : altLangName // ignore: cast_nullable_to_non_nullable
              as String?,
      isDownloading: null == isDownloading
          ? _value.isDownloading
          : isDownloading // ignore: cast_nullable_to_non_nullable
              as bool,
      downloadError: freezed == downloadError
          ? _value.downloadError
          : downloadError // ignore: cast_nullable_to_non_nullable
              as String?,
      hasAlternative: null == hasAlternative
          ? _value.hasAlternative
          : hasAlternative // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$L10nStateImpl extends _L10nState {
  const _$L10nStateImpl(
      {this.lang = 'en',
      this.version = 0,
      this.altLangCode,
      this.altLangName,
      this.isDownloading = false,
      this.downloadError,
      this.hasAlternative = false})
      : super._();

  /// Active language code: 'en' or whatever the gym configured (e.g. 'ka').
  @override
  @JsonKey()
  final String lang;

  /// Integer version of the cached alternative pack (0 = none cached).
  @override
  @JsonKey()
  final int version;

  /// Language CODE of the alternative language, e.g. 'ka'.
  /// Preserved when the user switches back to English so the flag pill
  /// always knows which alt flag to display.
  @override
  final String? altLangCode;

  /// Native-script display name for the alternative language, e.g. 'ქართული'.
  /// Null when no alternative language is configured.
  @override
  final String? altLangName;

  /// True while the language pack is downloading in the background.
  @override
  @JsonKey()
  final bool isDownloading;

  /// Set when a download attempt fails. Cleared by clearError().
  @override
  final String? downloadError;

  /// True once a valid alternative pack is loaded in the notifier.
  /// Drives visibility of the language toggle in Settings.
  @override
  @JsonKey()
  final bool hasAlternative;

  @override
  String toString() {
    return 'L10nState(lang: $lang, version: $version, altLangCode: $altLangCode, altLangName: $altLangName, isDownloading: $isDownloading, downloadError: $downloadError, hasAlternative: $hasAlternative)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$L10nStateImpl &&
            (identical(other.lang, lang) || other.lang == lang) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.altLangCode, altLangCode) ||
                other.altLangCode == altLangCode) &&
            (identical(other.altLangName, altLangName) ||
                other.altLangName == altLangName) &&
            (identical(other.isDownloading, isDownloading) ||
                other.isDownloading == isDownloading) &&
            (identical(other.downloadError, downloadError) ||
                other.downloadError == downloadError) &&
            (identical(other.hasAlternative, hasAlternative) ||
                other.hasAlternative == hasAlternative));
  }

  @override
  int get hashCode => Object.hash(runtimeType, lang, version, altLangCode,
      altLangName, isDownloading, downloadError, hasAlternative);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$L10nStateImplCopyWith<_$L10nStateImpl> get copyWith =>
      __$$L10nStateImplCopyWithImpl<_$L10nStateImpl>(this, _$identity);
}

abstract class _L10nState extends L10nState {
  const factory _L10nState(
      {final String lang,
      final int version,
      final String? altLangCode,
      final String? altLangName,
      final bool isDownloading,
      final String? downloadError,
      final bool hasAlternative}) = _$L10nStateImpl;
  const _L10nState._() : super._();

  @override

  /// Active language code: 'en' or whatever the gym configured (e.g. 'ka').
  String get lang;
  @override

  /// Integer version of the cached alternative pack (0 = none cached).
  int get version;
  @override

  /// Language CODE of the alternative language, e.g. 'ka'.
  /// Preserved when the user switches back to English so the flag pill
  /// always knows which alt flag to display.
  String? get altLangCode;
  @override

  /// Native-script display name for the alternative language, e.g. 'ქართული'.
  /// Null when no alternative language is configured.
  String? get altLangName;
  @override

  /// True while the language pack is downloading in the background.
  bool get isDownloading;
  @override

  /// Set when a download attempt fails. Cleared by clearError().
  String? get downloadError;
  @override

  /// True once a valid alternative pack is loaded in the notifier.
  /// Drives visibility of the language toggle in Settings.
  bool get hasAlternative;
  @override
  @JsonKey(ignore: true)
  _$$L10nStateImplCopyWith<_$L10nStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
