import 'dart:developer';

import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter/material.dart';

class MainActivity extends StatefulWidget {
  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  AudioInApp _audioInApp = AudioInApp();


  @override
  void initState() {
    super.initState();
    cargarCache();
    Future.delayed(Duration(milliseconds: 1500)).then((value) =>   reproducir2());
    Future.delayed(Duration(milliseconds: 3000)).then((value) =>   reproducir2());
    Future.delayed(Duration(milliseconds: 4000)).then((value) =>   reproducir2());
    Future.delayed(Duration(milliseconds: 4500)).then((value) =>   reproducir2());
  }

  Future<void> reproducir() async {
    await _audioInApp.play(playerId: 'intro');
  }
  Future<void> cargarCache() async {
    log(_audioInApp.audioCacheMap.toString(), name: 'LoadingActivity');
    /*await _audioInApp.createNewAudioCache(playerId: 'intro', route: 'audio/intro_2.wav', audioInAppType: AudioInAppType.background);
    await _audioInApp.createNewAudioCache(playerId: 'button', route: 'audio/button.wav', audioInAppType: AudioInAppType.determined);*/
    reproducir();
  }

  Future<void> reproducir2() async {
    await _audioInApp.play(playerId: 'button');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Main Activity'),
      ),
    );
  }
}