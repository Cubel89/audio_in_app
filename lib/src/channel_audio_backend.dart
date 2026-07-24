/// Internal abstraction over the audio engine used by background channels.
///
/// Keeping sources, buses, and voices generic lets the channel runtime be
/// exercised with deterministic fakes without initializing a native engine.
abstract interface class ChannelAudioBackend<Source, BusToken, VoiceToken> {
  /// Creates a bus owned by the caller. The bus is not necessarily audible yet.
  BusToken createBus({required String name});

  /// Whether [bus] can still be activated and used for playback.
  bool isBusUsable(BusToken bus);

  /// Makes [bus] audible and returns its master voice.
  VoiceToken activateBus(
    BusToken bus, {
    required double volume,
    bool paused = false,
  });

  /// Starts [source] looping through [bus] and returns the child voice.
  VoiceToken playLooping(
    BusToken bus,
    Source source, {
    required double volume,
    bool paused = false,
  });

  /// Whether [voice] represents an engine error rather than a live voice.
  bool isErrorVoice(VoiceToken voice);

  /// Whether [voice] is still valid in the engine.
  bool isVoiceValid(VoiceToken voice);

  /// Protects or unprotects [voice] from voice stealing.
  void setVoiceProtected(VoiceToken voice, bool protected);

  /// Reads the current per-voice volume.
  double getVoiceVolume(VoiceToken voice);

  /// Changes the per-voice volume immediately.
  void setVoiceVolume(VoiceToken voice, double volume);

  /// Changes the per-voice volume smoothly.
  void fadeVoiceVolume(
    VoiceToken voice, {
    required double to,
    required Duration duration,
  });

  /// Pauses or resumes [voice].
  void setVoicePaused(VoiceToken voice, bool paused);

  /// Whether [voice] is currently paused.
  bool isVoicePaused(VoiceToken voice);

  /// Stops [voice] without disposing its source.
  Future<void> stopVoice(VoiceToken voice);

  /// Disposes a bus owned by the caller and stops its child voices.
  void disposeBus(BusToken bus);
}
