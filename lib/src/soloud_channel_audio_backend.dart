import 'package:audio_in_app/src/channel_audio_backend.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// [ChannelAudioBackend] backed by flutter_soloud 4.0.7's mixing buses.
///
/// This adapter deliberately does not catch engine exceptions. The channel
/// runtime owns rollback and converts operational failures into its public
/// result type.
final class SoLoudChannelAudioBackend
    implements ChannelAudioBackend<AudioSource, Bus, SoundHandle> {
  const SoLoudChannelAudioBackend();

  @override
  Bus createBus({required String name}) {
    return SoLoud.instance.createMixingBus(name: name);
  }

  @override
  bool isBusUsable(Bus bus) {
    if (bus.busId <= 0) return false;
    final master = bus.soundHandle;
    return master == null || !master.isError;
  }

  @override
  SoundHandle activateBus(
    Bus bus, {
    required double volume,
    bool paused = false,
  }) {
    return bus.playOnEngine(volume: volume, paused: paused);
  }

  @override
  SoundHandle playLooping(
    Bus bus,
    AudioSource source, {
    required double volume,
    bool paused = false,
  }) {
    return bus.play(source, volume: volume, paused: paused, looping: true);
  }

  @override
  bool isErrorVoice(SoundHandle voice) => voice.isError;

  @override
  bool isVoiceValid(SoundHandle voice) {
    if (voice.isError) return false;
    return SoLoud.instance.getIsValidVoiceHandle(voice);
  }

  @override
  void setVoiceProtected(SoundHandle voice, bool protected) {
    SoLoud.instance.setProtectVoice(voice, protected);
  }

  @override
  double getVoiceVolume(SoundHandle voice) {
    return SoLoud.instance.getVolume(voice);
  }

  @override
  void setVoiceVolume(SoundHandle voice, double volume) {
    SoLoud.instance.setVolume(voice, volume);
  }

  @override
  void fadeVoiceVolume(
    SoundHandle voice, {
    required double to,
    required Duration duration,
  }) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative.');
    }
    if (duration == Duration.zero) {
      SoLoud.instance.setVolume(voice, to);
      return;
    }
    SoLoud.instance.fadeVolume(voice, to, duration);
  }

  @override
  void setVoicePaused(SoundHandle voice, bool paused) {
    SoLoud.instance.setPause(voice, paused);
  }

  @override
  bool isVoicePaused(SoundHandle voice) {
    return SoLoud.instance.getPause(voice);
  }

  @override
  Future<void> stopVoice(SoundHandle voice) {
    return SoLoud.instance.stop(voice);
  }

  @override
  void disposeBus(Bus bus) {
    bus.dispose();
  }
}
