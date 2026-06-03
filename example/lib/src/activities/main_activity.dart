import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter/material.dart';

class MainActivity extends StatefulWidget {
  const MainActivity({super.key});

  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  final AudioInApp _audioInApp = AudioInApp();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('audio_in_app Example')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Background audio section
              const Text(
                'Background Audio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Multiple backgrounds can play simultaneously:'),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('btn_play_intro1'),
                onPressed: () => _audioInApp.play(playerId: 'intro1'),
                child: const Text('Play intro 1'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_play_intro2'),
                onPressed: () => _audioInApp.play(playerId: 'intro2'),
                child: const Text('Play intro 2'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_stop_intro1'),
                onPressed: () => _audioInApp.stopBackground(playerId: 'intro1'),
                child: const Text('Stop intro 1 only'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_stop_intro2'),
                onPressed: () => _audioInApp.stopBackground(playerId: 'intro2'),
                child: const Text('Stop intro 2 only'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_stop_all_bg'),
                onPressed: () => _audioInApp.stopBackground(),
                child: const Text('Stop ALL backgrounds'),
              ),

              const SizedBox(height: 24),

              // Volume control section
              const Text(
                'Volume Control',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Change volume independently per audio:'),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('btn_vol_intro1_30'),
                onPressed: () => _audioInApp.setVol('intro1', 0.3),
                child: const Text('Intro 1 volume: 30%'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_vol_intro1_100'),
                onPressed: () => _audioInApp.setVol('intro1', 1.0),
                child: const Text('Intro 1 volume: 100%'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_vol_intro2_30'),
                onPressed: () => _audioInApp.setVol('intro2', 0.3),
                child: const Text('Intro 2 volume: 30%'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_vol_intro2_100'),
                onPressed: () => _audioInApp.setVol('intro2', 1.0),
                child: const Text('Intro 2 volume: 100%'),
              ),

              const SizedBox(height: 24),

              // Determined audio section
              const Text(
                'Determined Audio (SFX)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  'One-shot sounds. With SoLoud they overlap if retriggered:'),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const Key('btn_play_button'),
                onPressed: () => _audioInApp.play(playerId: 'button'),
                child: const Text('Play button sound'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_stop_button'),
                onPressed: () => _audioInApp.stop(playerId: 'button'),
                child: const Text('Stop button sound'),
              ),

              const SizedBox(height: 24),

              // Resource management section
              const Text(
                'Resource Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Release a cached audio and toggle global permission:'),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('btn_remove_intro1'),
                onPressed: () => _audioInApp.removeAudio('intro1'),
                child: const Text('Remove intro 1 from cache'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_toggle_permission'),
                onPressed: () {
                  setState(() {
                    _audioInApp.audioPermissionUser =
                        !_audioInApp.audioPermissionUser;
                  });
                },
                child: Text(
                  _audioInApp.audioPermissionUser
                      ? 'Disable audio (permission ON)'
                      : 'Enable audio (permission OFF)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
