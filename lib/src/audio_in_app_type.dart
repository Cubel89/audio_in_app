/// Defines where the audio is loaded from.
enum AudioInAppSource {
  /// Bundled asset under the `assets` folder (default, backwards compatible).
  /// The `route` is the asset path, e.g. `'audio/button.wav'`.
  asset,

  /// Local file on the device filesystem. The `route` is an absolute file
  /// path, e.g. `'/data/.../audios/note.m4a'`.
  ///
  /// Not supported on Web (uses `SoLoud.loadFile`, unavailable there); on Web,
  /// caching with this source fails gracefully and returns `false`.
  file,
}

/// Defines the type of audio playback behavior.
enum AudioInAppType {
  /// Short, one-shot audio (button clicks, sound effects).
  /// Plays once. Each play creates a new voice, so the same effect can overlap.
  determined,

  /// Looping background audio (music, ambient sounds).
  /// Loops continuously until stopped. Multiple background audios
  /// can play simultaneously with independent volume control.
  background,
}
