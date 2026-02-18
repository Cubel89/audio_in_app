import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter/material.dart';

class LoadingActivity extends StatefulWidget {
  const LoadingActivity({super.key});

  @override
  State<LoadingActivity> createState() => _LoadingActivityState();
}

class _LoadingActivityState extends State<LoadingActivity> {
  final AudioInApp _audioInApp = AudioInApp();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500)).then((_) => _goToMain());
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Loading audio...'),
      ),
    );
  }

  Future<void> _goToMain() async {
    await _audioInApp.createNewAudioCache(
      playerId: 'button',
      route: 'audio/button.wav',
      audioInAppType: AudioInAppType.determined,
    );
    await _audioInApp.createNewAudioCache(
      playerId: 'intro1',
      route: 'audio/intro_1.wav',
      audioInAppType: AudioInAppType.background,
    );
    await _audioInApp.createNewAudioCache(
      playerId: 'intro2',
      route: 'audio/intro_2.wav',
      audioInAppType: AudioInAppType.background,
    );

    if (mounted) {
      Navigator.pushReplacementNamed(context, 'main');
    }
  }
}
