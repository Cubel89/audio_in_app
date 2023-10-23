library audio_in_app;

import 'dart:developer';
import 'package:audio_in_app/audio_in_app.dart';
import 'package:audio_in_app/src/audio_in_app_type.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';



class AudioInApp with WidgetsBindingObserver {
  static const _NameLog = 'AudioInApp';
  bool _isRegistered = false;
  bool _audioPermission = true;

  Soundpool? _pool;
  SoundpoolOptions _soundpoolOptions = SoundpoolOptions();
  Map<String, dynamic> _soundsCache = {};




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
    _pool = Soundpool.fromOptions(options: _soundpoolOptions);
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


      if(audioInAppType == AudioInAppType.determined){
        ByteData _sound = await rootBundle.load(route);
        Map<String, dynamic> _info = {
          'library': 'soundpool',
          'id_sound': await _pool!.load(_sound),
          'route': route,
          'audioInAppType': audioInAppType,
          'volume': 1.0,
        };
        _soundsCache[playerId] = _info;
      }

      if(audioInAppType == AudioInAppType.background){
        ByteData _sound = await rootBundle.load(route);
        Map<String, dynamic> _info = {
          'library': 'soundpool',
          'id_sound': await _pool!.load(_sound),
          'route': route,
          'audioInAppType': audioInAppType,
          'volume': 1.0,
        };
        _soundsCache[playerId] = _info;
      }

      return true;


      AudioPlayer _audioPlayer = AudioPlayer(playerId: playerId);
      if(audioInAppType == AudioInAppType.determined){
        await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      } else if (audioInAppType == AudioInAppType.background){
        await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      }
      await _audioPlayer.setSourceAsset(route);

      Source _source = AssetSource(route);
      //await _audioPlayer.play(_source,volume: 1.0);
      //await _audioPlayer.stop();
      await _audioPlayer.setSource(_source);
      await _audioPlayer.setVolume(1.0);

      log('Ruta ${route}', name: _NameLog);
      log('Duracion ${await _audioPlayer.getDuration()}', name: _NameLog);

      Map<String, dynamic> _info = {
        'audioPlayer': _audioPlayer,
        'route': route,
        'source': _source,
        'audioInAppType': audioInAppType
      };
      _audioPlayerMap[playerId] = _info;
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
    if(_soundsCache[playerId]['audioInAppType'] == AudioInAppType.background){
      await _playBackground(playerId);
    }
    if(_soundsCache[playerId]['audioInAppType'] == AudioInAppType.determined){
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
      await _audioPlayerMap[playerId].stop();
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
    if(_soundsCache[playerId] == null){
      log('ERROR', name: _NameLog);
      log('PlayerID ${playerId} not is cached', name: _NameLog);
      log('Call the function "createNewAudioCache"', name: _NameLog);
      return false;
    }

    return true;
  }

  Future<void> _playDetermined(String playerId) async {
    log('Play playerID: ${playerId}', name: _NameLog);
    if(_soundsCache[playerId]['library'] == 'soundpool'){
      await _pool?.play(_soundsCache[playerId]['id_sound']);
      return;
    }
  }

  Future<void> _playBackground(String playerId) async {
    /*_audioBackgroundCacheList.forEach((String itemPlayerId) async {
      await _audioBackgroundCacheMap[itemPlayerId].stop();
    });*/


    log('Play Background playerID: ${playerId}', name: _NameLog);
    if(_soundsCache[playerId]['library'] == 'soundpool'){
      await _pool?.stop(_soundsCache[playerId]['id_sound']);
      await _pool?.play(_soundsCache[playerId]['id_sound'], repeat: 1);
    }
    log('FIN PAY Background playerID: ${playerId}', name: _NameLog);
    return;


    return;
    log('_playBackground ${playerId}', name: _NameLog);
    await _audioBackgroundCacheMap[playerId].resume();
    log('FIN _playBackground ${playerId}', name: _NameLog);
  }

  //Map<String, dynamic> get audioCacheMap => _audioCacheMap;

  Future<void> setVol(String playerId, double vol) async{
    if(! await _checkExistCache(playerId)) return;

    log('setVol playerID: ${playerId}, Vol: ${vol}', name: _NameLog);
    if(_soundsCache[playerId]['library'] == 'soundpool'){
      await _pool?.setVolume(soundId: _soundsCache[playerId]['id_sound'], volume: vol);
      return;
    }

    if(_audioPlayerMap[playerId]['audioInAppType'] == AudioInAppType.background){
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
    if(_audioCacheType[playerId]['audioInAppType'] == AudioInAppType.determined){
      AudioPlayer _audioPlayer = _audioPlayerMap[playerId]['audioPlayer'];
      await _audioPlayer.setVolume(vol);
      _audioPlayerMap[playerId]['audioPlayer'] = _audioPlayer;
    }

  }

  Future<bool> removeAudio(String playerId) async{
    if(!await _checkExistCache(playerId)) return false;
    if(_audioCacheType[playerId] == AudioInAppType.background){
      await _audioBackgroundCacheMap[playerId].dispose();
      _audioBackgroundCacheMap.removeWhere((key, value) => key == playerId);
    }
    if(_audioPlayerMap[playerId]['audioInAppType'] == AudioInAppType.determined){
      AudioPlayer _audioPlayer = _audioPlayerMap[playerId]['audioPlayer'];
      await _audioPlayer.dispose();
      _audioPlayerMap.removeWhere((key, value) => key == playerId);
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