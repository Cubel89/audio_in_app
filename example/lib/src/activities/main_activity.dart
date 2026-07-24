import 'dart:io';

import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class MainActivity extends StatefulWidget {
  const MainActivity({super.key});

  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  final AudioInApp _audioInApp = AudioInApp();

  // Status text for the isPlaying demo.
  String _isPlayingStatus = 'unknown (press "Check button" )';

  // Whether the local-file demo audio has already been prepared.
  bool _localFileReady = false;

  /// Copies a bundled asset to a temporary file and loads it as a LOCAL FILE
  /// (source: AudioInAppSource.file) using an absolute path. This demonstrates
  /// playing audio that does not live in the app bundle.
  Future<void> _prepareLocalFile() async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/button_copy.wav';

    final bytes = await rootBundle.load('assets/audio/button.wav');
    final file = File(filePath);
    await file.writeAsBytes(bytes.buffer.asUint8List());

    await _audioInApp.createNewAudioCache(
      playerId: 'localFile',
      route: filePath, // absolute path
      audioInAppType: AudioInAppType.determined,
      source: AudioInAppSource.file,
    );

    if (mounted) {
      setState(() => _localFileReady = true);
    }
  }

  void _checkIsPlaying(String playerId) {
    final playing = _audioInApp.isPlaying(playerId);
    setState(() {
      _isPlayingStatus = playing
          ? '"$playerId" is PLAYING'
          : '"$playerId" is NOT playing';
    });
  }

  // --- Demo de canales de fondo (crossfade), nuevo en 4.2.0 ---

  static const String _channelId = 'music';
  bool _channelReady = false;
  String _channelStatus = 'channel not created';

  /// Crea el canal exclusivo una sola vez. Un canal reproduce una pista a la
  /// vez y hace crossfade entre ellas.
  Future<void> _createChannel() async {
    final ok = await _audioInApp.createChannel(
      channelId: _channelId,
      volume: 0.8,
    );
    setState(() => _channelReady = ok);
    _refreshChannelStatus();
  }

  /// Reproduce [playerId] en el canal. Si ya sonaba otra pista, se cruzan
  /// durante [transition].
  Future<void> _playInChannel(String playerId, Duration transition) async {
    await _audioInApp.playChannel(
      channelId: _channelId,
      playerId: playerId,
      transitionDuration: transition,
    );
    _refreshChannelStatus();
  }

  Future<void> _pauseChannel() async {
    await _audioInApp.pauseChannel(channelId: _channelId);
    _refreshChannelStatus();
  }

  Future<void> _resumeChannel() async {
    await _audioInApp.resumeChannel(channelId: _channelId);
    _refreshChannelStatus();
  }

  Future<void> _stopChannel() async {
    await _audioInApp.stopChannel(
      channelId: _channelId,
      fadeOutDuration: const Duration(milliseconds: 800),
    );
    _refreshChannelStatus();
  }

  void _refreshChannelStatus() {
    final active = _audioInApp.activePlayerIdInChannel(_channelId);
    final playing = _audioInApp.isChannelPlaying(_channelId);
    final paused = _audioInApp.isChannelPaused(_channelId);
    setState(() {
      _channelStatus =
          'active: ${active ?? '—'} · playing: $playing · paused: $paused';
    });
  }

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

              // Background channels section (crossfade) — new in 4.2.0
              const Text(
                'Background Channels (crossfade)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'A channel plays ONE track at a time and crossfades between '
                'them. Create it once, then play tracks into it:',
              ),
              const SizedBox(height: 8),
              Text(
                _channelStatus,
                key: const Key('txt_channel_status'),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('btn_channel_create'),
                onPressed: _createChannel,
                child: const Text('Create channel'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_channel_play_intro1'),
                onPressed: _channelReady
                    ? () => _playInChannel('intro1', Duration.zero)
                    : null,
                child: const Text('Play intro 1 (instant)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_channel_crossfade_intro2'),
                onPressed: _channelReady
                    ? () =>
                          _playInChannel('intro2', const Duration(seconds: 2))
                    : null,
                child: const Text('Crossfade to intro 2 (2s)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_channel_crossfade_intro1'),
                onPressed: _channelReady
                    ? () =>
                          _playInChannel('intro1', const Duration(seconds: 2))
                    : null,
                child: const Text('Crossfade back to intro 1 (2s)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_channel_pause'),
                onPressed: _channelReady ? _pauseChannel : null,
                child: const Text('Pause channel'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_channel_resume'),
                onPressed: _channelReady ? _resumeChannel : null,
                child: const Text('Resume channel'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_channel_stop'),
                onPressed: _channelReady ? _stopChannel : null,
                child: const Text('Stop channel (fade 0.8s)'),
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

              const SizedBox(height: 24),

              // Local file source section (new in 4.1.0)
              const Text(
                'Local File Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Copy a bundled asset to a temp file and play it from an '
                'absolute path with source: AudioInAppSource.file:',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('btn_prepare_local_file'),
                onPressed: _prepareLocalFile,
                child: const Text('Prepare local file'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                key: const Key('btn_play_local_file'),
                onPressed: _localFileReady
                    ? () => _audioInApp.play(playerId: 'localFile')
                    : null,
                child: const Text('Play local file'),
              ),

              const SizedBox(height: 24),

              // isPlaying section (new in 4.1.0)
              const Text(
                'isPlaying',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Check whether a cached audio is still sounding:'),
              const SizedBox(height: 12),
              Text(
                _isPlayingStatus,
                key: const Key('txt_is_playing_status'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_check_button'),
                onPressed: () => _checkIsPlaying('button'),
                child: const Text('Check button'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('btn_check_intro1'),
                onPressed: () => _checkIsPlaying('intro1'),
                child: const Text('Check intro 1'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
