
import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter/material.dart';

class LoadingActivity extends StatefulWidget {
  @override
  State<LoadingActivity> createState() => _LoadingActivityState();
}

class _LoadingActivityState extends State<LoadingActivity> {
  AudioInApp _audioInApp = AudioInApp();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 1500)).then((value) =>   goToMain());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Loading Activity'),
      ),
    );
  }


  Future<void> goToMain() async {
    //_audioInApp.initialize();
    await _audioInApp.createNewAudioCache(playerId: 'button', route: 'assets/audio/button.wav', audioInAppType: AudioInAppType.determined);
    await _audioInApp.createNewAudioCache(playerId: 'intro1', route: 'assets/audio/intro_1.wav', audioInAppType: AudioInAppType.background);
    //await _audioInApp.createNewAudioCache(playerId: 'intro2', route: 'audio/intro_2.wav', audioInAppType: AudioInAppType.background);
    //log(_audioInApp._audioPlayerMap.toString(), name: 'LoadingActivity');

    Navigator.pushReplacementNamed(context, 'main');
  }
}