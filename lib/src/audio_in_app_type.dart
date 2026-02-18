/// Defines the type of audio playback behavior.
enum AudioInAppType {
  /// Short, one-shot audio (button clicks, sound effects).
  /// Plays once and stops. Uses low latency mode.
  determined,

  /// Looping background audio (music, ambient sounds).
  /// Loops continuously until stopped. Multiple background audios
  /// can play simultaneously with independent volume control.
  background,
}
