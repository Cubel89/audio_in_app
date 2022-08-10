library audio_in_app;

import 'dart:developer';
import 'package:audio_in_app/audio_in_app.dart';
import 'package:audio_in_app/src/audio_in_app_type.dart';
import 'package:audioplayers/audioplayers.dart';



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
      log('### A1', name: _NameLog);
      final AudioPlayer _audio = AudioPlayer(playerId: playerId);
      log('### A2', name: _NameLog);
      await _audio.setVolume(0.0);
      log('### A3', name: _NameLog);
      await _audio.setSource(AssetSource(route));
      log('### A4', name: _NameLog);
      await _audio.resume();
      await _audio.stop();
      await _audio.setVolume(1.0);
      log('### A5', name: _NameLog);
      if(audioInAppType == AudioInAppType.determined){
        log('### B1', name: _NameLog);
        await _audio.setReleaseMode(ReleaseMode.release);
        log('### B2', name: _NameLog);
        //await _audio.setPlayerMode(PlayerMode.lowLatency);
        log('### B3', name: _NameLog);
        _audioCacheMap[playerId] = _audio;
      }
      if(audioInAppType == AudioInAppType.background){
        log('### C1', name: _NameLog);
        await _audio.setReleaseMode(ReleaseMode.loop);
        log('### C2', name: _NameLog);
        //await _audio.setPlayerMode(PlayerMode.mediaPlayer);
        log('### C3', name: _NameLog);
        _audioBackgroundCacheMap[playerId] = _audio;
        if(!_audioBackgroundCacheList.contains(playerId)){
          log('### C4', name: _NameLog);
          _audioBackgroundCacheList.add(playerId);
        }
      }
      log('### A6', name: _NameLog);
      _audioCacheType[playerId] = audioInAppType;
      log('### A7', name: _NameLog);
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
    log('_playDetermined ${playerId}', name: _NameLog);
    log('State ${_audioCacheMap[playerId].state}', name: _NameLog);
    if(_audioCacheMap[playerId].state == PlayerState.playing){
      await _audioCacheMap[playerId].stop();
    }
    /*if(_audioCacheMap[playerId].isPlaying()){
      _audioCacheMap[playerId].stop();
    }*/
    await _audioCacheMap[playerId].resume();
    log('FIN _playDetermined ${playerId}', name: _NameLog);
  }

  Future<void> _playBackground(String playerId) async {
    _audioBackgroundCacheList.forEach((String itemPlayerId) async {
      await _audioBackgroundCacheMap[itemPlayerId].stop();
    });
    log('_playBackground ${playerId}', name: _NameLog);
    await _audioBackgroundCacheMap[playerId].resume();
    log('FIN _playBackground ${playerId}', name: _NameLog);
  }
}
