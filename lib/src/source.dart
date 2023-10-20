library audio_in_app;

import 'dart:developer';
import 'package:audio_in_app/audio_in_app.dart';
import 'package:audio_in_app/src/audio_in_app_type.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';



class AudioInApp with WidgetsBindingObserver {
  static const _NameLog = 'AudioInApp';
  bool _isRegistered = false;
  bool _audioPermission = true;


  Map<String, dynamic> _audioCacheMap = {};
  Map<String, dynamic> _audioPlayerMap = {};



  Map<String, dynamic> _audioCacheType = new Map<String, dynamic>();
  //Map<String, dynamic> _audioCacheMap = new Map<String, dynamic>();
  List<String> _audioBackgroundCacheList = <String>[];
  Map<String, dynamic> _audioBackgroundCacheMap = new Map<String, dynamic>();
  Map<String, dynamic> _audioBackgroundPlaying = {};



  /// Registers a [WidgetsBinding] observer.
  ///
  /// This must be called for auto-pause and resume to work properly.
  void _initialize() {
    if (_isRegistered) {
      return;
    }
    _isRegistered = true;
    _ambiguate(WidgetsBinding.instance)?.addObserver(this);
  }

  /// Dispose the [WidgetsBinding] observer.
  void dispose() {
    //audioPlayer.dispose();
    if (!_isRegistered) {
      return;
    }
    _ambiguate(WidgetsBinding.instance)?.removeObserver(this);
    _isRegistered = false;
  }

  //Singleton
  static final AudioInApp _singletonAudioInApp = new AudioInApp._internal();
  factory AudioInApp() {
    return _singletonAudioInApp;
  }
  AudioInApp._internal();

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      log('Entra en pausa', name: _NameLog);
      // went to Background
      _audioPermission = false;
      _audioBackgroundCacheList.forEach((String itemPlayerId) async {
        if(_audioBackgroundCacheMap[itemPlayerId].state == PlayerState.playing){
          await _audioBackgroundCacheMap[itemPlayerId].pause();
          _audioBackgroundPlaying['playerID'] = itemPlayerId;
        }
      });
    }
    if (state == AppLifecycleState.resumed) {
      log('Entra en play', name: _NameLog);
      // came back to Foreground
      _audioPermission = true;
      if(_audioBackgroundPlaying['playerID'] != null){
        await _audioBackgroundCacheMap[_audioBackgroundPlaying['playerID']].resume();
        _audioBackgroundPlaying = {};
      }
    }
  }





  /**
   * Functions Users
   * */
  Future<bool> createNewAudioCache({
    required String playerId,
    required String route,
    required AudioInAppType audioInAppType
  }) async{
    _initialize();
    try{
      AudioCache _audioCache = AudioCache();
      //AudioPlayer _audioPlayer = AudioPlayer(playerId: playerId);
      AudioPlayer _audioPlayer = AudioPlayer();
      await _audioCache.load(route);
      Map<String, dynamic> _info = {
        'audioCache': _audioCache,
        'route': route,
        'audioInAppType': audioInAppType
      };
      _audioCacheMap[playerId] = _info;


      _audioPlayer.setSourceAsset(route);
      _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      _audioPlayerMap[playerId] = _audioPlayer;
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
    if(!_audioPermission) return false;
    if(! await _checkExistCache(playerId)) return false;
    if(_audioCacheMap[playerId]['audioInAppType'] == AudioInAppType.background){
      await _playBackground(playerId);
    }
    if(_audioCacheMap[playerId]['audioInAppType'] == AudioInAppType.determined){
      await _playDetermined(playerId);
    }
    return true;
  }

  Future<bool> stop({
    required String playerId,
  }) async{
    if(! await _checkExistCache(playerId)) return false;
    if(_audioCacheType[playerId] == AudioInAppType.background){
      await _audioBackgroundCacheMap[playerId].stop();
    }
    if(_audioCacheType[playerId] == AudioInAppType.determined){
      await _audioCacheMap[playerId].stop();
    }
    return true;
  }

  Future<bool> stopBackgroun() async{
    _audioBackgroundCacheList.forEach((String itemPlayerId) async {
      await _audioBackgroundCacheMap[itemPlayerId].stop();
    });
    return true;
  }

  Future<bool> _checkExistCache(String playerId) async{
    //log('_audioPlayerMap ${_audioPlayerMap[playerId].toString()}', name: _NameLog);
    if(_audioCacheMap[playerId] == null){
      log('ERROR', name: _NameLog);
      log('PlayerID ${playerId} not is cached', name: _NameLog);
      log('Call the function "createNewAudioCache"', name: _NameLog);
      return false;
    }

    return true;
  }

  Future<void> _playDetermined(String playerId) async {

    final player = AudioPlayer();
    Source _ruta = AssetSource('audio/button.wav');
    await player.play(_ruta, mode: PlayerMode.lowLatency);
    return;

    // Reemplaza 'mi_cancion.mp3' con el nombre de tu archivo de audio.
    //String rutaCancion = 'mi_cancion.mp3';
    print(_audioPlayerMap[playerId].state);
    print(_audioPlayerMap[playerId].volume);
    print(_audioPlayerMap[playerId].state);
    if(_audioPlayerMap[playerId].state == PlayerState.playing){
      print('Entra en pause');
      await _audioPlayerMap[playerId].stop();
      await _audioPlayerMap[playerId].seek(Duration.zero);
      print('Sale en pause');
      _audioPlayerMap[playerId].state = PlayerState.completed;
    }
    print(_audioPlayerMap[playerId].state);
    await _audioPlayerMap[playerId].resume();


    print(_audioPlayerMap[playerId].state);
    //await _audioPlayerMap[playerId].seek(Duration.zero);
    await _audioPlayerMap[playerId].setVolume(1.0);

    return;
    log('_playDetermined ${playerId}', name: _NameLog);
    log('State ${_audioCacheMap[playerId]['audioCache'].player.isPlaying}', name: _NameLog);
    if(_audioCacheMap[playerId]['audioCache'].player.isPlaying){
      await _audioCacheMap[playerId]['audioCache'].stop();
    }
    /*if(_audioCacheMap[playerId].isPlaying()){
      _audioCacheMap[playerId].stop();
    }*/
    await _audioCacheMap[playerId]['audioCache'].play();
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

  Map<String, dynamic> get audioCacheMap => _audioCacheMap;

  Future<void> setVol(String playerId, double vol) async{
    if(! await _checkExistCache(playerId)) return;

    if(_audioCacheType[playerId] == AudioInAppType.background){
      _audioBackgroundCacheList.forEach((String itemPlayerId) async {
        if(itemPlayerId == playerId){
          if(_audioBackgroundCacheMap[itemPlayerId].state == PlayerState.playing){
            await _audioBackgroundCacheMap[itemPlayerId].pause();
            _audioBackgroundPlaying['playerID'] = itemPlayerId;
          }
          _audioBackgroundCacheMap[playerId].setVolume(vol);

          if(_audioBackgroundPlaying['playerID'] != null){
            if(vol > 0) {
              await _audioBackgroundCacheMap[_audioBackgroundPlaying['playerID']].resume();
            }
          }
          _audioBackgroundPlaying = {};
        }
      });
    }
    if(_audioCacheType[playerId] == AudioInAppType.determined){
      await _audioCacheMap[playerId].setVolume(vol);
    }

  }

  Future<bool> removeAudio(String playerId) async{
    if(!await _checkExistCache(playerId)) return false;
    if(_audioCacheType[playerId] == AudioInAppType.background){
      await _audioBackgroundCacheMap[playerId].dispose();
      _audioBackgroundCacheMap.removeWhere((key, value) => key == playerId);
    }
    if(_audioCacheType[playerId] == AudioInAppType.determined){
      await _audioCacheMap[playerId].dispose();
      _audioCacheMap.removeWhere((key, value) => key == playerId);
    }
    _audioCacheType.removeWhere((key, value) => key == playerId);
    _audioBackgroundCacheList.remove(playerId);
    return true;
  }
}

/// This allows a value of type T or T?
/// to be treated as a value of type T?.
///
/// We use this so that APIs that have become
/// non-nullable can still be used with `!` and `?`
/// to support older versions of the API as well.
///
/// See more: https://docs.flutter.dev/development/tools/sdk/release-notes/release-notes-3.0.0
T? _ambiguate<T>(T? value) => value;