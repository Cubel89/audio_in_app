import 'dart:developer';

import 'package:audio_in_app/audio_in_app.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class MainActivity extends StatefulWidget {
  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  AudioInApp _audioInApp = AudioInApp();
  final player = AudioPlayer();

  // Define the Map of the AudioPlayers
  final _audioPlayers = <int, AudioPlayer>{};

  @override
  void initState() {
    super.initState();
    //player.setSourceAsset('audio/button.wav');
    // Define a Pool of AudioPlayers
    const pool = 4;
    for (int i = 0; i < pool; i++) {
      // Create an AudioPlayer
      _audioPlayers[i] = AudioPlayer();
    }
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
    playSound();
  }
  Future<void> play_intro_2() async {
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