library audio_in_app;

import 'dart:developer';
import 'package:audio_in_app/src/audio_in_app_type.dart';
import 'package:audioplayers/audioplayers.dart';

export 'package:audio_in_app/src/audio_in_app_type.dart';

class AudioInApp {
  static const _NameLog = 'AudioInApp';

  Map<String, dynamic> _audioCacheType = new Map<String, dynamic>();
  Map<String, dynamic> _audioCacheMap = new Map<String, dynamic>();
  List<String> _audioBackgroundCacheList = <String>[];
  Map<String, dynamic> _audioBackgroundCacheMap = new Map<String, dynamic>();





  Future<bool> createNewAudioCache({
    required String playerId,
    required String route,
    required AudioInAppType audioInAppType
  }) async{
    try{
      final AudioPlayer _audio = AudioPlayer(playerId: playerId);
      await _audio.setVolume(0.0);
      await _audio.setSource(AssetSource(route));
      await _audio.resume();
      await _audio.stop();
      await _audio.setVolume(1.0);
      if(audioInAppType == AudioInAppType.determined){
        await _audio.setReleaseMode(ReleaseMode.release);
        await _audio.setPlayerMode(PlayerMode.lowLatency);
        _audioCacheMap[playerId] = _audio;
      }
      if(audioInAppType == AudioInAppType.background){
        await _audio.setReleaseMode(ReleaseMode.loop);
        await _audio.setPlayerMode(PlayerMode.mediaPlayer);
        _audioBackgroundCacheMap[playerId] = _audio;
        if(!_audioBackgroundCacheList.contains(playerId)){
          _audioBackgroundCacheList.add(playerId);
        }
      }

      _audioCacheType[playerId] = audioInAppType;
    } catch(e){
      log('ERROR', name: _NameLog);
      log(e.toString(), name: _NameLog);
      return false;
    }
    return true;
  }

  Future<bool> play({
    required String playerId,
  }) async{
    if(_audioCacheType[playerId] == null){
      log('ERROR', name: _NameLog);
      log('PlayerID ${playerId} not is cached', name: _NameLog);
      log('Call the function "createNewAudioCache"', name: _NameLog);
      return false;
    }
    if(_audioCacheType[playerId] == AudioInAppType.background){
      _playBackground(playerId);
    }
    if(_audioCacheType[playerId] == AudioInAppType.determined){
      await _playDetermined(playerId);
    }
    return true;
  }

  Future<void> _playDetermined(String playerId) async {
    await _audioCacheMap[playerId].resume();
  }

  Future<void> _playBackground(String playerId) async {
    _audioBackgroundCacheList.forEach((String itemPlayerId) async {
      await _audioBackgroundCacheMap[itemPlayerId].stop();
    });

    await _audioBackgroundCacheMap[playerId].resume();
  }
}
