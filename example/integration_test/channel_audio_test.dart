// Pruebas de integración de los canales de background con el motor SoLoud REAL.
//
// A diferencia de los tests unitarios (que usan un backend simulado), esto
// arranca el motor de verdad y valida que el MixingBus, los fades y el
// crossfade funcionan en el dispositivo/plataforma donde se ejecuta.
//
// Ejecutar:
//   flutter test integration_test/channel_audio_test.dart -d macos
//   flutter test integration_test/channel_audio_test.dart -d chrome
//
// El objetivo principal en Web es comprobar si `createMixingBus`, `bus.play` y
// `fadeVolume` de flutter_soloud funcionan sobre WASM.

import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final AudioInApp audio = AudioInApp();

  // Cachea dos pistas de fondo una sola vez. Si esto falla, es que el motor no
  // arrancó o no cargó los assets en esta plataforma.
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
    expect(bg1, isTrue, reason: 'El motor + carga de intro_1 debe funcionar.');
    expect(bg2, isTrue, reason: 'El motor + carga de intro_2 debe funcionar.');
  });

  // Deja el canal limpio entre pruebas (los canales persisten hasta detached).
  tearDown(() async {
    await audio.stopChannel(channelId: 'music');
  });

  testWidgets('crea un canal con Bus y reproduce la primera pista', (
    tester,
  ) async {
    expect(
      await audio.createChannel(channelId: 'music', volume: 0.8),
      isTrue,
      reason: 'createMixingBus debe funcionar en esta plataforma.',
    );
    expect(
      await audio.playChannel(channelId: 'music', playerId: 'intro1'),
      isTrue,
      reason: 'bus.play (voz hija en el bus) debe funcionar.',
    );
    expect(audio.isChannelPlaying('music'), isTrue);
    expect(audio.activePlayerIdInChannel('music'), 'intro1');
  });

  testWidgets('crossfade cambia la pista activa y limpia la saliente', (
    tester,
  ) async {
    await audio.createChannel(channelId: 'music', volume: 0.8);
    await audio.playChannel(channelId: 'music', playerId: 'intro1');

    // Cruce de 400 ms: durante el cruce coexisten ambas; al estabilizarse, B.
    expect(
      await audio.playChannel(
        channelId: 'music',
        playerId: 'intro2',
        transitionDuration: const Duration(milliseconds: 400),
      ),
      isTrue,
      reason: 'fadeVolume (entrante 0→v, saliente v→0) debe funcionar.',
    );
    // El objetivo lógico pasa a intro2 nada más aceptarse el cruce.
    expect(audio.activePlayerIdInChannel('music'), 'intro2');
    expect(audio.isChannelPlaying('music'), isTrue);

    // Esperamos a que termine el fade y corra la limpieza de la saliente.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(audio.activePlayerIdInChannel('music'), 'intro2');
    expect(audio.isChannelPlaying('music'), isTrue);
  });

  testWidgets('A→B→A reutiliza la voz de A sin dejarla huérfana', (
    tester,
  ) async {
    await audio.createChannel(channelId: 'music');
    await audio.playChannel(channelId: 'music', playerId: 'intro1');
    await audio.playChannel(
      channelId: 'music',
      playerId: 'intro2',
      transitionDuration: const Duration(milliseconds: 300),
    );
    // Volvemos a A antes de que B se estabilice del todo.
    await audio.playChannel(
      channelId: 'music',
      playerId: 'intro1',
      transitionDuration: const Duration(milliseconds: 300),
    );
    expect(audio.activePlayerIdInChannel('music'), 'intro1');

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(audio.activePlayerIdInChannel('music'), 'intro1');
    expect(audio.isChannelPlaying('music'), isTrue);
  });

  testWidgets('pausar y reanudar el canal', (tester) async {
    await audio.createChannel(channelId: 'music');
    await audio.playChannel(channelId: 'music', playerId: 'intro1');

    expect(await audio.pauseChannel(channelId: 'music'), isTrue);
    expect(audio.isChannelPaused('music'), isTrue);
    // Sigue "sonando" (una voz pausada se considera activa).
    expect(audio.isChannelPlaying('music'), isTrue);

    expect(await audio.resumeChannel(channelId: 'music'), isTrue);
    expect(audio.isChannelPaused('music'), isFalse);
    expect(audio.isChannelPlaying('music'), isTrue);
  });

  testWidgets('setChannelVolume no interrumpe el canal', (tester) async {
    await audio.createChannel(channelId: 'music', volume: 0.5);
    await audio.playChannel(channelId: 'music', playerId: 'intro1');

    expect(
      await audio.setChannelVolume(channelId: 'music', volume: 0.9),
      isTrue,
    );
    expect(audio.isChannelPlaying('music'), isTrue);
    expect(audio.activePlayerIdInChannel('music'), 'intro1');
  });

  testWidgets('stopChannel con fade deja el canal reutilizable', (tester) async {
    await audio.createChannel(channelId: 'music');
    await audio.playChannel(channelId: 'music', playerId: 'intro1');

    expect(
      await audio.stopChannel(
        channelId: 'music',
        fadeOutDuration: const Duration(milliseconds: 200),
      ),
      isTrue,
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(audio.activePlayerIdInChannel('music'), isNull);
    expect(audio.isChannelPlaying('music'), isFalse);

    // El canal sigue existiendo: se puede reutilizar sin recrearlo.
    expect(
      await audio.playChannel(channelId: 'music', playerId: 'intro2'),
      isTrue,
    );
    expect(audio.activePlayerIdInChannel('music'), 'intro2');
  });
}
