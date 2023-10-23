import 'dart:developer';

import 'package:audio_in_app/audio_in_app.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';

class MainActivity extends StatefulWidget {
  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  AudioInApp _audioInApp = AudioInApp();
  final player = AudioPlayer();

  // Define the Map of the AudioPlayers
  final _audioPlayers = <int, AudioPlayer>{};

  Soundpool? _pool;
  SoundpoolOptions _soundpoolOptions = SoundpoolOptions();
  int? _soundId1;
  int? _soundId2;


  @override
  void initState() {
    super.initState();

    /*if (!kIsWeb) {
      _initPool(_soundpoolOptions);
    }*/

    _initPool(_soundpoolOptions);
  }

  void _initPool(SoundpoolOptions soundpoolOptions) {
    _pool?.dispose();
    _soundpoolOptions = soundpoolOptions;
    _pool = Soundpool.fromOptions(options: _soundpoolOptions);
    print('pool updated: $_pool');
    _loadSounds();
  }

  void _loadSounds() async {
    var sound1Asset = await rootBundle.load("assets/audio/button.wav");
    var sound2Asset = await rootBundle.load("assets/audio/intro_1.wav");
    _soundId1 = await _pool!.load(sound1Asset);
    _soundId2 = await _pool!.load(sound2Asset);
  }

  Future<void> _playSound(int soundId) async {
    await _pool!.play(soundId);
  }
  // Para comprobar si el sonido se está reproduciendo
  bool isSoundPlaying(int soundId) {
    if (soundId != null) {
      final playbackState = _pool.getPlaybackState(streamId: soundId!);
      return playbackState == SoundpoolStreamType.Playing;
    }
    return false;
  }

  void playSound() {
    for (int i = 0; i < _audioPlayers.length; i++) {
      final currentAudioPlayer = _audioPlayers[i]!;
      // Find the AudioPlayer from the Pool which is not playing at this moment
      if (currentAudioPlayer.state != PlayerState.playing) {
        currentAudioPlayer.play(
          AssetSource('audio/button.wav'),
          mode: PlayerMode.lowLatency,
        );
        break;
      }
    }
  }


  Future<void> play_intro_1() async {
    //await _audioInApp.play(playerId: 'intro1');
    /*final player = AudioPlayer();
    Source _ruta = AssetSource('audio/intro_1.wav');
    await player.play(_ruta);*/
    //playSound();
    _playSound(_soundId1!);
  }
  Future<void> play_intro_2() async {
    _playSound(_soundId2!);
    return;
    //player.stop();
    //Source _ruta = AssetSource('audio/button.wav');
    //await player.stop();
    await player.seek(Duration(microseconds: 0));
    await player.stop();
    //await player.resume();
    //await player.play(_ruta, mode: PlayerMode.lowLatency);
    await player.resume();
    return;
    await _audioInApp.play(playerId: 'intro2');
  }
  Future<void> stop_background() async {
    await _audioInApp.stopBackgroun();
  }


  Future<void> play_button() async {
    await _audioInApp.play(playerId: 'button');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 30),
                child: Text('Main Activity')
            ),
            OutlinedButton(
              onPressed: () {
                play_intro_1();
              },
              child: Text("Play background intro 1"),
            ),
            OutlinedButton(
              onPressed: () {
                play_intro_2();
              },
              child: Text("Play background intro 2"),
            ),
            OutlinedButton(
              onPressed: () {
                play_button();
              },
              child: Text("Play Button Sound"),
            ),
            OutlinedButton(
              onPressed: () {
                stop_background();
              },
              child: Text("Stop background sound"),
            )
          ],
        ),
      ),
    );
  }
}