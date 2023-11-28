library audio_in_app;

import 'dart:developer';
import 'package:audio_in_app/audio_in_app.dart';
import 'package:audio_in_app/src/audio_in_app_type.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';



class AudioInApp with WidgetsBindingObserver {
  static const _NameLog = 'AudioInApp';
  bool _isRegistered = false;
  bool _audioPermission = true;
  bool _audioPermissionUser = true;

  Map<String, dynamic> _audioCacheType = {};
  Map<String, dynamic> _audioCacheMap = {};
  List<String> _audioBackgroundCacheList = [];
  Map<String, dynamic> _audioBackgroundCacheMap = {};
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
      log('Paused', name: _NameLog);
      // went to Background
      _audioPermission = false;
      _audioBackgroundCacheList.forEach((String itemPlayerId) async {
        if(_audioBackgroundCacheMap[itemPlayerId] != null){
          if(_audioBackgroundCacheMap[itemPlayerId].state == PlayerState.playing){
            await _audioBackgroundCacheMap[itemPlayerId].pause();
            _audioBackgroundPlaying['playerID'] = itemPlayerId;
          }
        }
      });
    }
    if (state == AppLifecycleState.resumed) {
      log('Resumed', name: _NameLog);
      // came back to Foreground
      _audioPermission = true;
      if(_audioBackgroundPlaying['playerID'] != null && _audioPermissionUser){
        await _audioBackgroundCacheMap[_audioBackgroundPlaying['playerID']].resume();
        _audioBackgroundPlaying = {};
      }
    }
  }





  /// Methods Users
  ///
  /// Method to add the audio in cache. (Required before you can play).
  Future<bool> createNewAudioCache({
    required String playerId,
    required String route,
    required AudioInAppType audioInAppType
  }) async{
    _initialize();
    log('createNewAudioCache $playerId', name: _NameLog);
    try{
      if(audioInAppType == AudioInAppType.determined){
        final AudioPlayer _audio = AudioPlayer(playerId: playerId,);
        await _audio.setVolume(0.0);
        await _audio.setSource(AssetSource(route));
        await _audio.setReleaseMode(ReleaseMode.stop);
        if(Platform.isIOS){
          await _audio.resume();
          await _audio.stop();
        }

        await _audio.setVolume(1.0);

        await _audio.setPlayerMode(PlayerMode.lowLatency);
        _audioCacheMap[playerId] = _audio;

        if(!_audioBackgroundCacheList.contains(playerId)){
          _audioBackgroundCacheList.add(playerId);
        }
      }

      if(audioInAppType == AudioInAppType.background){
        final AudioPlayer _audio = AudioPlayer(playerId: playerId,);
        await _audio.setVolume(0.0);
        await _audio.setSource(AssetSource(route));
        if(Platform.isIOS){
          await _audio.resume();
          await _audio.stop();
        }

        await _audio.setVolume(1.0);

        await _audio.setReleaseMode(ReleaseMode.loop);
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

  /// Method to start playing the audio
  Future<bool> play({
    required String playerId,
  }) async{
    if(!_audioPermission) return false;
    if(!_audioPermissionUser) return false;
    log('play $playerId', name: _NameLog);
    if(! await _checkExistCache(playerId)) return false;
    if(_audioCacheType[playerId] == AudioInAppType.background){
      await _playBackground(playerId);
    }
    if(_audioCacheType[playerId] == AudioInAppType.determined){
      await _playDetermined(playerId);
    }
    return true;
  }

  /// Method to stop the audio
  Future<bool> stop({
    required String playerId,
  }) async{
    log('stop $playerId', name: _NameLog);
    if(! await _checkExistCache(playerId)) return false;
    if(_audioCacheType[playerId] == AudioInAppType.background){
      await _audioBackgroundCacheMap[playerId].stop();
    }
    if(_audioCacheType[playerId] == AudioInAppType.determined){
      await _audioCacheMap[playerId].stop();
    }
    return true;
  }


  /// Method to stop background audio no matter what audio is playing
  Future<bool> stopBackground() async{
    _audioBackgroundCacheList.forEach((String itemPlayerId) async {
      if(_audioBackgroundCacheMap[itemPlayerId] != null){
        await _audioBackgroundCacheMap[itemPlayerId].stop();
      }
    });
    return true;
  }

  Future<bool> _checkExistCache(String playerId) async{
    if(_audioCacheType[playerId] == null){
      log('ERROR', name: _NameLog);
      log('PlayerID $playerId not is cached', name: _NameLog);
      log('Call the function "createNewAudioCache"', name: _NameLog);
      return false;
    }

    return true;
  }

  Future<void> _playDetermined(String playerId) async {
    log('_playDetermined $playerId', name: _NameLog);
    if(_audioCacheMap[playerId].state == PlayerState.playing){
      await _audioCacheMap[playerId].stop();
    }
    await _audioCacheMap[playerId].resume();
  }

  Future<void> _playBackground(String playerId) async {
    _audioBackgroundCacheList.forEach((String itemPlayerId) async {
      if(_audioBackgroundCacheMap[itemPlayerId] != null){
        await _audioBackgroundCacheMap[itemPlayerId].stop();
      }
    });
    log('_playBackground $playerId', name: _NameLog);
    await _audioBackgroundCacheMap[playerId].resume();
  }

  Map<String, dynamic> get audioCacheMap => _audioCacheMap;


  bool get audioPermissionUser => _audioPermissionUser;

  /// By default it will be set to "true", but if set to "false" no cached sound will play.
  set audioPermissionUser(bool value) {
    _audioPermissionUser = value;
  }

  /// Change the audio volume. Value between 0.0 and 1.0
  Future<void> setVol(String playerId, double vol) async{
    log('setVol $playerId', name: _NameLog);
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

  /// Delete the audio from the cache. It will no longer play again until it is re-cached using the "createNewAudioCache" method
  Future<bool> removeAudio(String playerId) async{
    log('removeAudio $playerId', name: _NameLog);
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