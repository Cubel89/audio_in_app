// Pruebas de integración (motor SoLoud REAL) de dos cosas:
//   1. Regresión de la API 4.1.1: los canales nuevos no deben romper el
//      comportamiento antiguo (backgrounds múltiples, stop selectivo, determined
//      solapado, isPlaying).
//   2. Coexistencia: el MISMO playerId puede sonar a la vez como voz "legacy"
//      (play/stopBackground) y como voz canalizada, y las operaciones legacy
//      que amplían alcance (stop, setVol, isPlaying) alcanzan a ambas.
//
// Ejecutar:  flutter test integration_test/legacy_and_coexistence_test.dart -d macos

import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final AudioInApp audio = AudioInApp();

  setUpAll(() async {
    final bg1 = await audio.createNewAudioCache(
      playerId: 'intro1',
      route: 'audio/intro_1.wav',
      audioInAppType: AudioInAppType.background,
    );
    final bg2 = await audio.createNewAudioCache(
      playerId: 'intro2',
      route: 'audio/intro_2.wav',
      audioInAppType: AudioInAppType.background,
    );
    final sfx = await audio.createNewAudioCache(
      playerId: 'button',
      route: 'audio/button.wav',
      audioInAppType: AudioInAppType.determined,
    );
    expect(bg1 && bg2 && sfx, isTrue, reason: 'El motor debe cachear los tres.');
  });

  // Deja todo en silencio entre pruebas.
  tearDown(() async {
    await audio.stopBackground();
    await audio.stopChannel(channelId: 'music');
  });

  group('Regresión API 4.1.1', () {
    testWidgets('varios backgrounds simultáneos e independientes', (
      tester,
    ) async {
      expect(await audio.play(playerId: 'intro1'), isTrue);
      expect(await audio.play(playerId: 'intro2'), isTrue);
      expect(audio.isPlaying('intro1'), isTrue);
      expect(audio.isPlaying('intro2'), isTrue);

      // stopBackground selectivo: para solo intro1, intro2 sigue.
      expect(await audio.stopBackground(playerId: 'intro1'), isTrue);
      expect(audio.isPlaying('intro1'), isFalse);
      expect(audio.isPlaying('intro2'), isTrue);

      // stopBackground global: para el resto.
      expect(await audio.stopBackground(), isTrue);
      expect(audio.isPlaying('intro2'), isFalse);
    });

    testWidgets('play de background es idempotente (no duplica voz)', (
      tester,
    ) async {
      expect(await audio.play(playerId: 'intro1'), isTrue);
      // Un segundo play mientras suena no debe reventar ni crear otra voz viva.
      expect(await audio.play(playerId: 'intro1'), isTrue);
      expect(audio.isPlaying('intro1'), isTrue);
    });

    testWidgets('determined se dispara y se puede parar sin afectar al fondo', (
      tester,
    ) async {
      await audio.play(playerId: 'intro1');
      expect(await audio.play(playerId: 'button'), isTrue);
      // El one-shot no debe tumbar el background.
      expect(audio.isPlaying('intro1'), isTrue);
      expect(await audio.stop(playerId: 'button'), isTrue);
      expect(audio.isPlaying('intro1'), isTrue);
    });

    testWidgets('setVol sobre una pista viva no la interrumpe', (tester) async {
      await audio.play(playerId: 'intro1');
      await audio.setVol('intro1', 0.3);
      expect(audio.isPlaying('intro1'), isTrue);
      await audio.setVol('intro1', 1.0);
      expect(audio.isPlaying('intro1'), isTrue);
    });
  });

  group('Coexistencia legacy + canal por mismo playerId', () {
    testWidgets('la misma pista suena como legacy y como canal a la vez', (
      tester,
    ) async {
      // Voz legacy de intro1.
      await audio.play(playerId: 'intro1');
      expect(audio.isPlaying('intro1'), isTrue);

      // Voz canalizada de intro1 (voz distinta, misma fuente).
      await audio.createChannel(channelId: 'music', volume: 0.8);
      expect(
        await audio.playChannel(channelId: 'music', playerId: 'intro1'),
        isTrue,
      );
      expect(audio.activePlayerIdInChannel('music'), 'intro1');
      expect(audio.isChannelPlaying('music'), isTrue);
      expect(audio.isPlaying('intro1'), isTrue);
    });

    testWidgets('stop(playerId) alcanza a la voz legacy Y a la canalizada', (
      tester,
    ) async {
      await audio.play(playerId: 'intro1');
      await audio.createChannel(channelId: 'music', volume: 0.8);
      await audio.playChannel(channelId: 'music', playerId: 'intro1');

      // stop legacy debe limpiar ambas instancias del mismo id.
      expect(await audio.stop(playerId: 'intro1'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(audio.isPlaying('intro1'), isFalse);
      expect(audio.activePlayerIdInChannel('music'), isNull);
      expect(audio.isChannelPlaying('music'), isFalse);
    });

    testWidgets('recachear un id activo en un canal se rechaza', (tester) async {
      await audio.createChannel(channelId: 'music');
      await audio.playChannel(channelId: 'music', playerId: 'intro1');
      // Mientras intro1 está vivo en el canal, no se puede recachear ese id.
      final recache = await audio.createNewAudioCache(
        playerId: 'intro1',
        route: 'audio/intro_1.wav',
        audioInAppType: AudioInAppType.background,
      );
      expect(recache, isFalse);
    });
  });
}
