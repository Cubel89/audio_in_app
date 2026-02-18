## 3.0.0

* **BREAKING**: Updated audioplayers from ^5.2.0 to ^6.5.1
* **BREAKING**: Minimum Dart SDK raised to >=3.6.0
* **BREAKING**: Minimum Flutter SDK raised to >=3.13.0
* **BREAKING**: Removed `audioCacheMap` getter (use `cachedPlayerIds` instead)
* **BREAKING**: Multiple background audios can now play simultaneously (previously, playing one stopped all others)
* Removed `universal_io` dependency (replaced with `flutter/foundation.dart` for web compatibility)
* Added web platform support
* Independent volume control per background audio
* Improved type safety (proper types instead of dynamic)
* Fixed async forEach anti-pattern (was not awaiting iterations)
* Removed deprecated `_ambiguate` helper
* Code quality improvements and full API documentation

## 2.1.1

* Error correction

## 2.1.0

* Updated the "audioplayers" version to 5.2.0
* Error correction

## 2.0.0 (Do not use this version because it gives an error.)

* Updated the "audioplayers" version to 5.2.0
* Error correction


## 1.0.0

* Load the audio to be able to use it later
* Play background audio
* Play punctual audio
* Delete cached loaded audio
* Change sound volume
